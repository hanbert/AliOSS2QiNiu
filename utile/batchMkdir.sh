#! /bin/bash
#By HXH 2018.01.29

sourFile="prefixFileList.txt"
count=0
while read line
do
    let count++
    path=${line%/*}
    echo $path
    mkdir -p $path
    echo "第 $count 文件夹创建完毕"
done < $sourFile
