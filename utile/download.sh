#! /bin/bash
#By HXH 2018.01.29

sourFile="unsuccessList.txt"
count=0
while read line
do
    let count++
    URL=$(echo $line | awk '{print $1}')
    fileName=$(echo $line | awk '{$1=""; print $0}' | sed 's/^[ \t]*//g')
    fileName=$(echo \"$fileName\")
    echo $URL
    echo $fileName
    curl -C - "$URL" -o $count --progress
    mv $count $fileName
    echo "第 $count 文件下载完成"
done < $sourFile
