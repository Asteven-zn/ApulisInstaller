## Apulis AI Platform Installer

### 一.部署整体流程介绍

- 从github下载安装脚本

- 修改安装程序配置文件

- 执行安装程序

- 部署完成登录平台

  ***注意：服务器必须可以访问 Internet*

### 二.部署执行链路

prepare fiel -> install docker -> install kubernetes -> node lable -> install nfs ->  install aiarts (apply)

### 三.部署实操作

#### 1.从github 下载安装包

```shell
cd /home && git clone https://github.com/Asteven-zn/ApulisInstaller.git
```

- 安装包说明

  ```shell
  InstallApulis
  ├── app.tar.gz         用到的二进制文件
  ├── build              aiarts的yaml文件
  │   ├── apply.sh       aiarts脚本
  ├── credentials        认证信息文件
  ├── daemon.json
  ├── docker.sh          docker脚本
  ├── install.sh         部署主程序
  ├── k8s.sh             kubernetes脚本
  ├── lab.sh             node lable脚本
  ├── nfs.sh             nfs-server脚本
  ├── nginxfile.tar.gz
  └── remove.sh          卸载平台脚本
  └── nginxfile.tar.gz   nginx相关配置文件
  ```

#### 2.进入安装包目录

```shell
cd /home/InstallApulis
```

#### 3.修改install.sh 主安装脚本配置

将 eth_ip 参数改为本地服务器的业务网卡 IP 地址，如下：

```shell
#/bin/bash

#配置服务器的网卡ip地址
eth_ip=192.168.2.156
......
............
..................
```

#### 4.部署完成

讲到如下输出内容，平台部署完成

```shell
Apulis AI Platform Installer succeed
```

