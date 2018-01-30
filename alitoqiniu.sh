#! /bin/bash
#By HXH 2018.01.29

#获取当前脚本的绝对路径
path=$(cd "$(dirname $0)"; pwd)

#设置或显示当前用户的 AccessKey 和 SecretKey
function setAccount()
{
    local AccessKey="$1"
    local SecretKey="$2"

    $path/bin/qshell account $AccessKey $SecretKey

    echo "当前用户设置为："
    $path/bin/qshell account
}

#获取阿里云OSS空间中的文件外链列表
function getAliOSSList()
{   
    local DataCenter="$1"
    local Bucket="$2"
    local AccessKeyId="$3"
    local AccessKeySecret="$4"
    local fileList="$5"
    local fileLinkList="$6"

    #获取AliOSS云空间文件列表
    if [ -z $Prefix ]; then
        $path/bin/qshell alilistbucket $DataCenter $Bucket $AccessKeyId $AccessKeySecret $fileList
    else
        $path/bin/qshell alilistbucket $DataCenter $Bucket $AccessKeyId $AccessKeySecret $Prefix $fileList
    fi

    #对文件列表的文件名进行urlecode编码
    tempFile=".urlencode"

    #去除每一行最后两串数字，并删除原文件列表
    cat $fileList | awk '{$NF=$(NF-1)=""; print $0}' > $tempFile
    rm -f $fileList

    #检查文件列表是否还存在，如果存在，删除文件列表
    if [ -e $fileList ]; then
        rm -f $fileList
    fi

    #对去除后面两串数字的文件列表，逐行进行编码，然后写回文件列表
    while read line
    do
        $path/bin/qshell urlencode "$line" >> $fileList
    done < $tempFile
    rm -f $tempFile

    #检查临时文件列表是否还存在，如果存在，删除临时文件列表
    if [ -e $tempFile ]; then
        rm -f $tempFile
    fi

    #将文件列表转换成相应的文件外链列表
    if [ -s $fileList ]; then
        if [ -z $Prefix ]; then
            header="http://${Bucket}.${DataCenter}/"
            cat $fileList | awk -v header=$header '{print header$0}' > $fileLinkList
        else
            header="http://${Bucket}.${DataCenter}/$Prefix"
            cat $fileList | awk -v header=$header '{print header$0}' > $fileLinkList
        fi
    else
        echo "获取文件列表失败."
    fi

    #判断文件外链列表转换成功，并统计文件数目
    if [ -e $fileLinkList ]; then
        fileCount=$(wc -l $path/$fileLinkList | awk '{print $1}')
        echo "成功获取到AliOSS云空间文件列表，共有 $fileCount 个文件."
    else 
        echo "获取文件列表失败."
    fi
}

#转换AliOSS文件外链列表的的格式
function formatFileLinkList()
{
    local fileLinkList="$1"
    local cutIndex=$2
    tempResult=".tempResult"

    #如果文件已经存在则清空文件
    if [ -s $tempResult ]; then
        cat /dev/null > $tempResult
    fi

    #一行一行读取并处理
    while read line
    do
        #从这一行末尾添加文件名
        fileName=${line:$cutIndex}
        #对fileName进行urldecode解码
        fileName=$($path/bin/qshell urldecode "$fileName")
        echo $line | awk -v fileName="$fileName" '{print $0"\t"fileName}' >> $tempResult
    done < $fileLinkList

    #将文件重命名
    if [ -s $tempResult ]; then
        mv $tempResult $fileLinkList
    fi
}

#将AliOSS的文件同步到Qiniu云空间
function fetchFile()
{
    local AccessKey="$1"
    local SecretKey="$2"
    local Bucket="$3"
    local fileList="$4"
    local worker="$5"
    local jobName="$6"
    local logDir="$path/log"

    #检查log文件夹是否存在，如果不存在，则创建
    if [ ! -d $logDir ]; then
        mkdir -p $logDir
    elif [ -e $logDir/$jobName.log ]; then
        DATE=$(date +%Y-%m-%d-%H:%M:%S)
        mv $logDir/$jobName.log $logDir/${jobName}${DATE}.log
    fi    

    #检查任务名字和并行数是否指定，如果指定，则运行同步任务
    if [ -z $jobName ]; then
        echo "任务名字不能够为空"
    elif [ -z $worker ]; then
        echo "请指定任务并行数"
    else
        $path/bin/qfetch -ak=$AccessKey -sk=$SecretKey -bucket=$Bucket -file=$fileList -worker=$worker -job=$jobName | tee $path/log/$jobName.log
    fi

    #判断是否同步完毕
    fileCount=$(wc -l $path/$fileList | awk '{print $1}')
    successFileCount=$($path/bin/leveldb -count=".$jobName.job")
    if [ $fileCount -eq $successFileCount ]; then
        echo "全部同步完毕，共同步 $successFileCount 个文件."
    else
        echo "共有 $fileCount 个文件，成功同步 $successFileCount 个文件."
        remainingFileCount=`expr $fileCount - $successFileCount`
        echo "还剩余 $remainingFileCount 个文件未传输完毕."
        echo "请再次执行 $jobName 任务，将会自动跳过已同步文件."
    fi
}

#根据前缀获取AliOSS的文件列表
function getPrefixFlieList()
{   
    local DataCenter="$1"
    local Bucket="$2"
    local AccessKeyId="$3"
    local AccessKeySecret="$4"
    local fileList="$5"
    local fileLinkList="$6"
    prefixFile="Prefix.txt"
    prefixFileList=".prefixFileList"
    prefixFileLinkList=".prefixFileLinkList"

    #检查Prefix列表文件是否存在
    if [ -e $prefixFile ]; then
        if [ ! -s $prefixFile ]; then
            echo "请在Prefix.txt文件中输入相应的前缀，可以多个，每行一个."
        fi
    else 
        touch $Prefix
        echo "请在Prefix.txt文件中输入相应的前缀，可以多个，每行一个."
    fi
    
    #如果文件已经存在则删除
    if [ -s $fileList ]; then
        rm -f $fileList
    fi
    #如果文件已经存在则删除
    if [ -s $fileLinkList ]; then
        rm -f $fileLinkList
    fi

    count=1
    for prefix in `cat $prefixFile`
    do
        Prefix=$prefix
        echo "============================================================"
        echo "$count: 获取 $Prefix 为前缀的文件."
        getAliOSSList $DataCenter $Bucket $AccessKeyId $AccessKeySecret $prefixFileList $prefixFileLinkList
        cat $prefixFileList >> $fileList
        cat $prefixFileLinkList >> $fileLinkList
        let count++
    done
    rm -f $prefixFileList $prefixFileLinkList
    
    #检查文件是否还存在，如果存在，删除文件
    if [ -e $prefixFileList ]; then
        rm -f $prefixFileList
    fi
    #检查文件是否还存在，如果存在，删除文件
    if [ -e $prefixFileLinkList ]; then
        rm -f $prefixFileLinkList
    fi

    echo "============================================================"
    fileCount=$(wc -l $path/$fileLinkList | awk '{print $1}')
    echo "文件列表获取完毕，共有 $fileCount 个文件."
    echo "============================================================"
}

################################################
#### 前期基础条件准备，需要根据实际情况相应修改 ####
################################################

#Qiniu用户的 AccessKey、SecretKey 和 Bucket
QiniuAccessKey="xxxxx"
QiniuSecretKey="xxxxx"
QiniuBucket="xxxxx"

#AliOSS用户的 AccessKeyId、AccessKeySecret、数据中心和 Bucket
AliAccessKeyId="xxxxx"
AliAccessKeySecret="xxxx"
AliDataCenter="xxxxx" 
AliBucket="xxxxx"

#想要获取的AliOSS文件的前缀，可选项目，默认为空
#如果想要修改请类比于如下格式：“data/attachment/forum/201801/25/”
Prefix=""

#AliOSS文件列表和文件外链列表
AliFileList="AliFileList.txt"
AliFileLinkList="AliFileLinkList.txt"

###############################################
################# 运行同步任务 #################
###############################################

#同步的任务名称和并行数，其中并行数要考虑带宽容量极限，过大可能导致频繁失败
read -p "请输入任务名称：" jobName
read -p "请输入任务的并行数(并行数要考虑带宽容量极限，过大可能导致单个任务频繁失败)：" worker

echo "设置Qiniu用户"
setAccount $QiniuAccessKey $QiniuSecretKey

echo "获取AliOSS文件列表"
read -p "是否需要指定前缀(y or n): " flag
if [ $flag = "n" ]; then
    getAliOSSList $AliDataCenter $AliBucket $AliAccessKeyId $AliAccessKeySecret $AliFileList $AliFileLinkList
else
    getPrefixFlieList $AliDataCenter $AliBucket $AliAccessKeyId $AliAccessKeySecret $AliFileList $AliFileLinkList
fi

echo "转换AliOSS文件列表格式"
cutIndex=60
formatFileLinkList $AliFileLinkList $cutIndex
echo "开始同步"
fetchFile $QiniuAccessKey $QiniuSecretKey $QiniuBucket $AliFileLinkList $worker $jobName

