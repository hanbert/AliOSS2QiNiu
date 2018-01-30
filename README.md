# AliOSS2QiNiu
本项目主要是为了将论坛的附件由阿里云OSS批量迁移到七牛云存储而开发的。

## 主要内容说明

`alitoqiniu.sh` 主程序文件，需要根据自己的实际情况填写AliOSS的AK、SK、Bucket，以及七牛云的AK、SK、Bucket。

`bin` 目录下是七牛云提供的一些工具，可以从七牛云官网下载到。

`utile` 目录下主要放置了一些处理特殊情况的脚本。

`utlie/findDiff.sh` 找出两个文件列表中不同的地方，主要用来将原始文件列表和同步成功的文件列表对比，找出未能同步成功的文件列表。

`utlie/download.sh` 根据文件列表第一个字段的下载地址，自动下载文件

`utile/batchMkdir.sh` 根据文件列表，批量创建目录

