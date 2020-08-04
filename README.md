# InstallationYTung -- Creation of Installation Script for DLWorkspace
## Table of Contents

## 关于

此repository是针对YTung Workspace Installation 产生 Installation Disk。 并支持无网状态下的安装。

### 环境准备

1. Nvidia-driver 440.33
2. Nvidia GPUs
3. Cuda 10.2
4. Ubuntu 18.04
5. The *X86* architecture system

### 1. 使用install_pan.sh进行安装盘制作

```shel
./install_pan.sh -c -d <docker_images_directory> -p <install_dirrectory>
```

#### 参数解释

* -c：在下载安装所需的apt package的时候，同时下载依赖包。
* -d：指向docker镜像的存放目录，该路径应当在根目录下存放所有镜像的tar打包文件，并且没有其他文件或者目录。。
* -p：指向安装目录，该目录在脚本运行结束后需要拷贝到目标主机。

#### 注意事项

1. 请使用root用户执行脚本。
2. 使用脚本时，在实例命令中将"<>"内的内容替换为相应的路径位置。

2. 使用安装脚本的主机与安装目标主机需要拥有相同的操作系统、架构类型，并保证apt安装源最新。

3. 执行完成后，安装目录应当有以下文件和文件夹：

* install_DL.sh
* install_workernode.sh

- YTung.tar.gz
- config目录
- apt目录
- docker-images目录
- python2.7目录

### 2. 将安装目录拷贝到安装目标主机上

### 3. 进行安装前的配置检查

检查内容

* 需要在master节点来执行install_DL.sh

* 所有主机已经配置好root用户，并且拥有密码。

* 所有安装GPU的主机都安装好nvidia 440版本驱动。

* 确保master节点上/etc/hosts文件中已经配置好了集群所有节点（包括master自身的）的域名解析，包括短域名和长域名。短域名需要与主机名相同，长域名以：**主机名.sigsus.cn**的形式配置。

  例如，master节点主机名为ubuntu-master,则/etc/hosts文件中至少应该有以下两条记录：

  ​	xxx.xxx.xxx.xxx ubuntu-master

  ​	xxx.xxx.xxx.xxx ubuntu-master.sigsus.cn

* 请确保config.yaml文件配置与集群信息匹配，如果不知道config.yaml文件的配置情况，请与管理员联系。

### 4. 使用install_DL.sh进行安装

请按照提示完成安装，按照顺序，你应当会遇到以下需要输入的内容：

1. 欢迎界面，请按回车继续。

2. 条款确认，请输入yes继续。

3. 是否允许将master节点当作worker调度，请选择yes。（仅限于测试版本）

4. 配置worker节点信息，将会需要输入节点域名，请注意此时应当输入短域名，该短域名与该worker主机名相同；

   在配置节点信息的部分，请在任何需要确认的部分输入yes确认来完成节点间的knownhost配置，并在需要输入密码的部分输入root那么；

   配置完第一个节点以后，可以继续配置节点（此时应该是需要输入下一个节点的域名），也可以输入”quit“退出配置。

安装时间比较长，请保持耐心等待。

