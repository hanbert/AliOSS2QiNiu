#! /bin/bash
#By HXH 2018.01.29

sourceFile="AliFileLinkList.txt"
targetFile="successList.txt"
#sourceFile="test1.txt"
#targetFile="test2.txt"
unsuccessList="unsuccessList.txt"
flag="ok"
count=0
countSourceLine=0
countTargetLine=0

if [ -e $unsuccessList ]; then
    rm -f $unsuccessList
fi

#找出两个文件中不同的行
#不能用管道符来循环，那样while循环中的变量值传不出来
#用重定向符来度文件
while read -r sourceLine
do
    #echo $sourceLine
    let countSourceLine+=1
    echo "================ 第 $countSourceLine 条数据 ================"    
    while read -r targetLine
    do
        #echo $targetLine
        countTargetLine=$(($countTargetLine + 1))
        echo -e "\t匹配第 $countTargetLine 条数据"
        if [ "$sourceLine" = "$targetLine" ]; then
            flag="no"
            break
        fi
    done < $targetFile
    
    if [ "$flag" = "ok" ]; then
        ((count++))
        echo "#######################################"
        echo "###### 找到第 $count 条不匹配数据 #######"
        echo "#######################################"
        echo $sourceLine >> $unsuccessList
    else
        echo "已经找到匹配项"
        flag="ok"
    fi

    countTargetLine=0
done < $sourceFile

echo "==========================================="
echo "@@@@@@ 分析完毕，共找到 $count 条数据 @@@@@@@"
echo "==========================================="
