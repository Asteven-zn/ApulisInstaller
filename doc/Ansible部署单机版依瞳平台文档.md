# 依赖准备

## 系统准备
- 系统安装盘下载链接: http://old-releases.ubuntu.com/releases/18.04.1/
- 系统安装链接: https://support.huawei.com/enterprise/zh/doc/EDOC1100136592/426cffd9

## 驱动准备
- 驱动下载链接：https://ascend.huawei.com/#/hardware/firmware-drivers
- 驱动安装链接：https://support.huaweicloud.com/instg-msInstall-cann202/atlasms_03_0002.html




# 安装部署



## 安装流程

单机场景下的安装流程如图1所示。

图1 单机部署安装流程


## 环境说明

本文提供了**使用Ansible部署依瞳人工智能平台单机版**的方式，以Atlas 800训练服务器为例子，安装环境应满足以下要求：

表1 安装环境要求

| 软件名称           | 版本        |
| ------------------ | ----------- |
| 操作系统           | Ubuntu18.04.1 |
| NPU驱动            | CANN 20.1      |
| 依瞳平台部署安装包 | v1.5.0      |

须知：依瞳平台部署安装包可用于部署在不同架构类型的机器，ARM架构和x86架构可以使用同一个安装包。

## 单机部署组网方案

### 组网方案1

Ansible管理节点、kubernetes集群的master、worker节点均部署在一台Atlas 800 训练服务器上，按照图2所示进行逻辑组网。

图2 单机部署方案1


### 组网方案2

Ansible管理节点部署在通用服务器上，kubernetes集群的master、worker节点均部署在一台Atlas 800 训练服务器上，按照图3所示进行逻辑组网。

图3 单机部署方案2


须知：

- 使用第二种方案进行部署时，需确保Ansible管理节点所在机器能够访问训练服务器。
- **本文使用第一种组网方案来进行部署**，即将Atlas训练服务器作为Ansible的管理节点。





## 配置环境依赖

**前提条件：**

- 已完成操作系统的安装。
- 已完成NPU驱动的安装。

本文按照组网方案1，Ansible管理节点、kubernetes集群的master、worker节点均部署在一台Atlas 800 训练服务器上。

**部署节点的相关信息如下：**

- 管理节点：192.168.3.9（内网）（将集群的master作为Ansible的管理节点）
- 集群节点（被管理节点）：
  - 192.168.3.9（内网）（master）
  - 192.168.3.9（内网）（worker01）

### 配置免密登录

- 1、使用**root用户**登录管理节点（192.168.3.9）

- 2、在管理节点生成ssh-key

  ```
  ssh-keygen -t rsa -b 2048 -N ''（一直回车即可）
  ```

- 3、将管理节点的公钥拷贝到所有被管理节点的机器上：

  ```
  ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.3.9
  ```

- 4、检查管理节点能否ssh免密登录到被管理节点：

  ```
  ssh root@192.168.3.9
  ```

注意：**如果没有特别标注，本文中的所有执行命令都默认使用root用户执行。**

### 安装pip

- 1、以**root用户**登录所有被管理节点（192.168.3.9）

- 2、部署过程中可能需要通过pip下载package。ubuntu 18.04系统默认自带python3，不再需要手动安装，但需要确保pip3能用。查看系统默认的python和pip版本：

  ```sh
  python --version
  # Python 3.7.5
  
  pip --version
  # pip 20.2.2 from /usr/local/lib/python3.7/dist-packages/pip (python 3.7)
  ```

- 2、如果pip不能使用，需要安装一下：

  ```
  apt install python3-pip
  ```

### 安装netaddr

在被管理节点（192.168.3.9）安装netaddr，有下列两种安装方式：

```
使用pip安装：pip install netaddr -i https://pypi.tuna.tsinghua.edu.cn/simple netaddr

使用pip3安装：pip3 install netaddr -i https://pypi.tuna.tsinghua.edu.cn/simple netaddr
```



## 安装Ansible

- 1、使用**root用户**登录管理节点（192.168.3.9）

- 2、安装ansible的方式有多种，下面为常用的两种方式：

  - 2.1、第一种方式：apt安装

    ```
    apt update
    apt install software-properties-common
    apt-add-repository --yes --update ppa:ansible/ansible
    apt install ansible
    ```

  - 2.2、第二种方式：pip安装

    ```
    pip config set global.index-url https://mirrors.aliyun.com/pypi/simple && \
    pip config set install.trusted-host mirrors.aliyun.com
    pip install --user ansible
    ```

- 3、查看Ansible的版本。

  ```
  ansbible --version
  ```


**注意：**

1. 使用上面的apt方式安装Ansible的时候，需要注意apt的源，测试过程中发现使用华为apt源安装Ansible可能会有点问题。
2. 安装好Ansible后，需要特别注意Ansible的版本，由于Ansible版本更新升级很快，使用旧的版本Ansible会导致有些模块功能用不了。**最好是2.9或者2.10等以上的版本。**
3. 第一种方式安装（apt安装）提供了4条命令，全部都要执行，不能只执行`apt install ansible`，否则，可能导致下载的Ansible版本为2.5版本，版本不够新，从而导致后面的部署失败。



## 修改配置文件



cd 进入到依瞳平台安装包的根目录：

```
cd InstallationYTung
```

安装包存在以下内容：

```
01.prepare.yaml      06.kube-init.yaml       90.setup.yaml           95.reset-cluster.yaml  credentials  install_pan.sh  README.md       tools
02.etcd.yaml         07.harbor.yaml          91.aiarts-start.yaml    ansible.cfg            doc          Jenkinsfile     resources       upgrade_doc.md
03.docker.yaml       08.network.yaml         92.aiarts-stop.yaml     bin                    download     LICENSE         roles
04.kube-master.yaml  09.storage.yaml         93.aiarts-restart.yaml  compress_harbor.sh     group_vars   macros          scripts
05.kube-worker.yaml  10.aiarts-service.yaml  94.reset-harbor.yaml    config                 hosts        manifests       service_ctl.sh
```




### 修改hosts文件

hosts文件的路径是：InstallationYTung/hosts

主要可修改内容如下：

- 1、在 [etcd] 下填写etcd的安装节点（ip）
- 2、在 [kube-master] 下填写k8s集群的master节点（ip）
- 3、在 [kube-worker] 下填写k8s集群的worker节点（ip）。有多个worker节点时，直接换行填写即可。
- 4、在 [nfs-server] 下填写nfs安装节点（ip）
- 5、在 [harbor] 下填写harbor的安装节点（ip)

注意：单机部署时，直接将对应的ip改成被管理节点的ip即可。

下面是hosts文件的内容：

```sh
# 'etcd' cluster should have odd member(s) (1,3,5,...)
# variable 'NODE_NAME' is the distinct name of a member in 'etcd' cluster
[etcd]
192.168.3.9 NODE_NAME=etcd1 

# master node(s)
[kube-master]
192.168.3.9

# work node(s)
[kube-worker]
192.168.3.9

[cluster:children]
kube-master
kube-worker

[nfs-server]
192.168.3.9

# [optional] harbor server, a private docker registry
# 'NEW_INSTALL': 'yes' to install a harbor server; 'no' to integrate with existed one
# 'SELF_SIGNED_CERT': 'no' you need put files of certificates named harbor.pem and harbor-key.pem in directory 'down'
[harbor]
192.168.3.9 NEW_INSTALL=yes SELF_SIGNED_CERT=yes

# [optional] loadbalance for accessing k8s from outside
[ex-lb]
#192.168.1.6 LB_ROLE=backup EX_APISERVER_VIP=192.168.1.250 EX_APISERVER_PORT=8443
#192.168.1.7 LB_ROLE=master EX_APISERVER_VIP=192.168.1.250 EX_APISERVER_PORT=8443

# [optional] ntp server for the cluster
[chrony]
#192.168.1.1

```


### 修改all.yaml文件

all.yaml文件的路径：InstallationYTung/group_vars/all.yaml

主要可修改的内容为：

- 1、项目名称：PROJECT_NAME: "huawei"，这个名称将作为集群harbor保存镜像的项目名称
- 2、集群harbor域名：HARBOR_DOMAIN: "harbor.huawei.cn"
- 3、集群harbor端口：HARBOR_HTTPS_PORT: 8443
- 4、每个镜像的name和tag（包括基础镜像和服务镜像）。建议保持不变。

下面是all.yaml文件的内容：

```yaml
# Project Name
PROJECT_NAME: "huawei"

PLATFORM_NAME: "Apulis"

# the name of cluster
CLUSTER_NAME: "DLWS"

# -------- Additional Variables (don't change the default value right now)---
# Binaries Directory
i18n: "zh-CN"

bin_dir: "/opt/kube/bin"

# CA and other components cert/key Directory
ca_dir: "/etc/kubernetes/ssl"

# Deploy Directory (aiarts workspace)
base_dir: "{{ lookup('env', 'PWD') }}"

# resource directory (include apt, images, dlws code and other package)
resource_dir: "{{base_dir}}/resources"

# --------- Main Variables ---------------
CONTAINER_RUNTIME: "docker"

# Network plugins supported: calico, flannel, kube-router, cilium, kube-ovn
CLUSTER_NETWORK: "weavenet"

# Service proxy mode of kube-proxy: 'iptables' or 'ipvs'
PROXY_MODE: "iptables"

# K8S Service CIDR, not overlap with node(host) networking
SERVICE_CIDR: "10.68.0.0/16"

# Cluster CIDR (Pod CIDR), not overlap with node(host) networking
CLUSTER_CIDR: "172.20.0.0/16"

# NodePort Range
NODE_PORT_RANGE: "20000-40000"

# Cluster DNS Domain
CLUSTER_DNS_DOMAIN: "cluster.local"

# harbor domain value
HARBOR_DOMAIN: "harbor.yunxia.cn"

# harbor https port
HARBOR_HTTPS_PORT: 8443

# CPU Architecture
arch_map:
  i386: "386"
  x86_64: "amd64"
  aarch64: "arm64"
  armv7l: "armv7"
  armv6l: "armv6"

thirdparty_images:
  grafana:
    name: "apulistech/grafana"
    tag: "6.7.4"
  grafana-zh:
    name: "apulistech/grafana-zh"
    tag: "6.7.4"
  a910-device-plugin:
    name: "apulistech/a910-device-plugin"
    tag: "devel3"
  alibi-explainer:
    name: ""
  atc:
    name: "apulistech/atc"
    tag: "0.0.1"
  visualjob:
    name: "apulistech/visualjob"
    tag: "1.0"
  tensorflow:
    name: "apulistech/tensorflow"
    tag: "1.14.0-gpu-py3"
  pytorch:
    name: "apulistech/pytorch"
    tag: "1.5"
  mxnet:
    name: "apulistech/mxnet"
    tag: "2.0.0-gpu-py3"
  ubuntu:
    name: "apulistech/ubuntu"
    tag: "18.04"
  bash:
    name: "bash"
    tag: "5"
  k8s-prometheus-adapter:
    name: "directxman12/k8s-prometheus-adapter"
    tag: "v0.7.0"
  tensorflow-serving:
    name: "apulistech/tensorflow-serving"
    tag: "1.15.0"
  tensorrtserver:
    name: ""
  kfserving-pytorchserver:
    name: "apulistech/kfserving-pytorchserver"
    tag: "1.5.1"
  knative-serving:
    name: ""
  kfserving-logger:
    name: ""
  golang:
    name: "golang"
    tag: "1.13.7-alpine3.11"
  prometheus-operator:
    name: "jessestuart/prometheus-operator"
    tag: "v0.38.0"
  coredns:
    name: "k8s.gcr.io/coredns"
    tag: "1.6.7"
  etcd:
    name: "k8s.gcr.io/etcd"
    tag: "3.4.3-0"
  kube-apiserver:
    name: "k8s.gcr.io/kube-apiserver"
    tag: "v1.18.2"
  kube-controller-manager:
    name: "k8s.gcr.io/kube-controller-manager"
    tag: "v1.18.2"
  kube-proxy:
    name: "k8s.gcr.io/kube-proxy"
    tag: "v1.18.2"
  kube-scheduler:
    name: "k8s.gcr.io/kube-scheduler"
    tag: "v1.18.2"
  pause:
    name: "k8s.gcr.io/pause"
    tag: "3.2"
  mysql-server:
    name: "mysql/mysql-server"
    tag: "8.0"
  postgresql:
    name: "postgres"
    tag: "11.10-alpine"
  nvidia-device-plugin:
    name: "nvidia/k8s-device-plugin"
    tag: "1.11"
  kube-vip:
    name: "plndr/kube-vip"
    tag: "0.1.8"
  alertmanager:
    name: "prom/alertmanager"
    tag: "v0.20.0"
  node-exporter:
    name: "prom/node-exporter"
    tag: "v0.18.1"
  prometheus:
    name: "prom/prometheus"
    tag: "v2.18.0"
  redis:
    name: "redis"
    tag: "5.0.6-alpine"
  weave-kube:
    name: "weaveworks/weave-kube"
    tag: "2.7.0"
  weave-npc:
    name: "weaveworks/weave-npc"
    tag: "2.7.0"
  xgbserver:
    name: ""
  sklearnserver:
    name: ""
  onnxruntime-server:
    name: ""
  vc-scheduler:
    name: "vc-scheduler"
    tag: "v0.0.1"
  vc-webhook-manager:
    name: "vc-webhook-manager"
    tag: "v0.0.1"
  vc-controller-manager:
    name: "vc-controller-manager"
    tag: "v0.0.1"
  ascend-k8sdeviceplugin:
    name: "ascend-k8sdeviceplugin"
    tag: "v0.0.1"
  reaper:
    name: ""

apulis_images:
  apulisvision:
    name: "apulistech/apulisvision"
    tag: "1.2.1"
  aiarts-backend:
    name: "apulistech/aiarts-backend"
    tag: "v1.5.0-rc4"
  aiarts-frontend:
    name: "dlworkspace_aiarts-frontend"
    tag: "v1.5.0-rc4"
  custom-user-dashboard-backend:
    name: "dlworkspace_custom-user-dashboard-backend"
    tag: "v1.5.0-rc4"
  custom-user-dashboard-frontend:
    name: "dlworkspace_custom-user-dashboard-frontend"
    tag: "v1.5.0-rc4"
  data-platform-backend:
    name: "apulistech/dlworkspace_data-platform-backend"
    tag: "latest"
  gpu-reporter:
    name: "apulistech/dlworkspace_gpu-reporter"
    tag: "latest"
  image-label:
    name: "apulistech/dlworkspace_image-label"
    tag: "latest"
  init-container:
    name: "apulistech/dlworkspace_init-container"
    tag: "latest"
  openresty:
    name: "apulistech/dlworkspace_openresty"
    tag: "latest"
  repairmanager2:
    name: "apulistech/repairmanager2"
    tag: "latest"
  restfulapi2:
    name: "apulistech/restfulapi2"
    tag: "v1.5.0-rc4"
  webui3:
    name: "dlworkspace_webui3"
    tag: "v1.5.0-rc4"
  job-exporter:
    name: "apulistech/job-exporter"
    tag: "1.9"
  nginx:
    name: "apulistech/nginx"
    tag: "1.9"
  node-cleaner:
    name: "node-cleaner"
    tag: "latest"
  watchdog:
    name: "apulistech/watchdog"
    tag: "1.9"
  istio-proxy:
    name: "apulistech/istio-proxy"
    tag: "latest"
  istio-pilot:
    name: "apulistech/istio-pilot"
    tag: "latest"
  knative-serving-webhook:
    name: "apulistech/knative-serving-webhook"
    tag: "latest"
  knative-serving-queue:
    name: "apulistech/knative-serving-queue"
    tag: "latest"
  knative-serving-controller:
    name: "apulistech/knative-serving-controller"
    tag: "latest"
  knative-serving-activator:
    name: "apulistech/knative-serving-activator"
    tag: "latest"
  knative-serving-autoscaler:
    name: "apulistech/knative-serving-autoscaler"
    tag: "latest"
  knative-net-istio-webhook:
    name: "apulistech/knative-net-istio-webhook"
    tag: "latest"
  knative-net-istio-controller:
    name: "apulistech/knative-net-istio-controller"
    tag: "latest"
  kfserving-manager:
    name: "apulistech/kfserving-manager"
    tag: "latest"
  kfserving-storage-initializer:
    name: "apulistech/kfserving-storage-initializer"
    tag: "latest"
  kfserving-kube-rbac-proxy:
    name: "apulistech/kfserving-kube-rbac-proxy"
    tag: "latest"
  mlflow:
    name: "apulistech/mlflow"
    tag: "v1.0.0"

```



### 修改cluster.yaml文件

cluster.yaml文件的路径是：InstallationYTung/group_vars/cluster.yaml

主要可修改的内容为：

- 1、kube vip地址：kube_vip_address: "192.168.3.9" （使用master的ip即可）

下面是cluster.yaml文件的内容：

```yaml
MASTER_AS_WORKER: true

container_mount_path: /dlwsdata
physical_mount_path: /mntdlws

manifest_dest: "/root/build"
user_name: dlwsadmin
default_cni_path: /opt/cni/bin

# kube vip address
kube_vip_address: "192.168.3.9"

# Network plugins supported: calico, flannel, kube-router, cilium, kube-ovn
CLUSTER_NETWORK: "weavenet"

# Service proxy mode of kube-proxy: 'iptables' or 'ipvs'
PROXY_MODE: "iptables"

# K8S Service CIDR, not overlap with node(host) networking
SERVICE_CIDR: "10.68.0.0/16"

# Cluster CIDR (Pod CIDR), not overlap with node(host) networking
CLUSTER_CIDR: "172.20.0.0/16"

# NodePort Range
NODE_PORT_RANGE: "20000-40000"

# Cluster DNS Domain
CLUSTER_DNS_DOMAIN: "cluster.local"

# cluster api address
cluster_api_address: "{{ kube_vip_address if kube_vip_address is defined else groups['kube-master'][0]}}"

# 平台类型，决定了可以启动多少服务
PLATFORM_MODE: "express"

datasource: postgres

modes:
  preview:
    - storage
    - network
    - a910-device-plugin
    - nvidia-device-plugin
    - postgres
    - restfulapi2
    - custom-user-dashboard
    - jobmanager2
    - custommetrics
    - monitor
    - nginx
    - openresty
    - webui3
    - aiarts-backend
    - aiarts-frontend
    - mlflow
    - image-label
    - data-platform
    - volcanosh
    - istio
    - kfserving
    - knative
  express:
    - storage
    - network
    - a910-device-plugin
    - nvidia-device-plugin
    - postgres
    - restfulapi2
    - custom-user-dashboard
    - jobmanager2
    - custommetrics
    - monitor
    - nginx
    - openresty
    - webui3
    - aiarts-backend
    - aiarts-frontend
    - mlflow
    - image-label
    - data-platform
    - volcanosh
    - istio
    - kfserving
    - knative
  professional:
    - storage
    - network
    - a910-device-plugin
    - nvidia-device-plugin
    - postgres
    - restfulapi2
    - custom-user-dashboard
    - jobmanager2
    - custommetrics
    - monitor
    - nginx
    - openresty
    - webui3
    - aiarts-backend
    - aiarts-frontend
    - mlflow
    - image-label
    - data-platform
    - volcanosh
    - istio
    - kfserving
    - knative

# the unified image tag
image_tag: "v1.2.0"
```



### 修改harbor.yaml文件

harbor.yaml文件的路径是：InstallationYTung/group_vars/harbor.yaml

主要可修改内容为：

- 1、集群harbor存储数据的路径：HARBOR_LOCATION: "/data"  （建议修改成存储空间较大的路径）

  ```
  HARBOR_LOCATION: "/data"
  ```

  

### 检查管理节点能否ping通所有的被管理节点

在InstallationYTung路径下，执行以下命令，检查管理节点能否ping通所有的被管理节点：

```
ansible all -i hosts -m ping
```

成功的结果信息可类比下图，确保是**SUCCESS**状态：（警告信息可忽略）




**:hammer:此步失败或报错了怎么办？**

- 1、检查命令是否在InstallationYTung路径下执行，如果不是，会提示类似以下的信息：


- 2、检查 InstallationYTung/hosts 文件是否编辑填写正确





## 执行部署脚本

**确保下面所有的ansible-playbook命令都是在`InstallationYTung`路径下执行。**

按顺序执行下面的命令：

```sh
ansible-playbook -i hosts 01.prepare.yaml
```

```sh
ansible-playbook -i hosts 02.etcd.yaml
```

```sh
ansible-playbook -i hosts 03.docker.yaml
```

```sh
ansible-playbook -i hosts 04.kube-master.yaml
```

```sh
ansible-playbook -i hosts 05.kube-worker.yaml
```

```sh
ansible-playbook -i hosts 06.kube-init.yaml
```

```sh
ansible-playbook -i hosts 07.harbor.yaml
```

```sh
ansible-playbook -i hosts 08.network.yaml
```

```sh
ansible-playbook -i hosts 09.storage.yaml
```

```sh
ansible-playbook -i hosts 10.aiarts-service.yaml
```

注意：

- 1、每一步的执行结果需要确保failed=0：


- 2、被ignore掉的报错可以忽略：


- 3、执行03.docker.yaml一步之后，需要检查docker有没有安装成功

  ```
  systemctl status docker
  ```


- 4、执行06.kube-init.yaml一步之后，需要检查kubernetes集群包含的节点和状态（STATUS为Ready）：

  ```
  kubectl get nodes
  ```

- 5、执行08.harbor.yaml之后，集群harbor被搭建起来了，可通过以下信息验证harbor是否可用，以及部署所需镜像是否都推送到了harbor上：

  - 访问地址：harbor.huawei.cn:8443（可从all.yaml文件的配置中获得）
  - 用户名：admin
  - 密码：可在InstallationYTung/credentials/harbor.pwd中查看

- 6、执行 10.aiarts-service.yaml 是用来启动平台所有的服务的，执行完此步没有报错后，**部署就完成了**。接下来就是去测试平台的服务正不正常，以及检查各种pod的状态等。

- 7、ansible部署遵循幂等性，每一个步骤都可以重复执行。



## 部署后检查

1、检查平台能否正常登录：192.168.3.9（直接使用kube-vip进行登录）

2、检查平台页面是否正常

3、检查平台是否可以正常进行训练等各项功能



# 更新镜像

**通过manifest方式推送新的镜像到集群harbor的方式：**

1. 修改InstallationYTung/group_vars/all.yaml文件中对应的镜像name和tag

2. 将新的镜像的tar包放在InstallationYTung/resources/images目录下

   1. tar包的名称没有限制（尽量写规范点，能够标识包里的imageName,tag,镜像架构等）

   2. tar包里面的镜像的名称有限制：

      1. 必须带有/amd64或者/arm64来表示镜像的架构类型，如：
         
         harbor.sigsus.cn:8443/sz_gongdianju/apulistech/tensorflow-serving/amd64:1.15.0
         
         harbor.atlas.cn:8443/sz_gongdianju/apulistech/tensorflow-npu/arm64:1.15-20.1.RC1

      2. 镜像name和tag必须与all.yaml一致


3. 执行`ansible-playbook -i hosts 08.harbor.yaml`（这个playbook会帮助我们推送新的镜像到集群harbor中）

更新了镜像之后，我们可能需要重拉镜像来**重启某个服务**，方式是：

```sh
ansible-playbook -i hosts 93.aiarts-restart.yaml -e sn=serviceName
或者：
service_ctl.sh restart ${serviceName}
```

- `serviceName`指的是服务的名称，可在`InstallationYTung/manifests/services`目录下查看：

```sh
root@master:~/test/InstallationYTung/manifests/services# ll
总用量 104
drwxr-xr-x 26 root root 4096 1月  13 19:05 ./
drwxr-xr-x  5 root root 4096 1月  13 19:05 ../
drwxr-xr-x  2 root root 4096 1月  16 15:00 a910-device-plugin/
drwxr-xr-x  2 root root 4096 1月  18 15:48 aiarts-backend/
drwxr-xr-x  2 root root 4096 1月  13 19:05 aiarts-frontend/
drwxr-xr-x  2 root root 4096 1月  13 19:05 cAdvisor/
drwxr-xr-x  2 root root 4096 1月  13 19:05 custommetrics/
drwxr-xr-x  2 root root 4096 1月  13 19:05 custom-user-dashboard/
drwxr-xr-x  2 root root 4096 1月  16 15:00 data-platform/
drwxr-xr-x  2 root root 4096 1月  13 19:05 device-plugin/
drwxr-xr-x  2 root root 4096 1月  13 19:05 image-label/
drwxr-xr-x  2 root root 4096 1月  13 19:05 istio/
drwxr-xr-x  2 root root 4096 1月  13 19:05 jobmanager2/
drwxr-xr-x  2 root root 4096 1月  13 19:05 kfserving/
drwxr-xr-x  2 root root 4096 1月  16 15:00 knative/
drwxr-xr-x  2 root root 4096 1月  13 19:05 mlflow/
drwxr-xr-x  8 root root 4096 1月  19 17:31 monitor/
drwxr-xr-x  2 root root 4096 1月  13 19:05 mysql/
drwxr-xr-x  3 root root 4096 1月  13 19:05 nginx/
drwxr-xr-x  2 root root 4096 1月  13 19:05 node-cleaner/
drwxr-xr-x  2 root root 4096 1月  13 19:05 nvidia-device-plugin/
drwxr-xr-x  2 root root 4096 1月  13 19:05 openresty/
drwxr-xr-x  2 root root 4096 1月  13 19:05 postgres/
drwxr-xr-x  2 root root 4096 1月  13 19:05 restfulapi2/
drwxr-xr-x  2 root root 4096 1月  15 11:29 volcanosh/
drwxr-xr-x  2 root root 4096 1月  16 15:00 webui3/
```


# FAQ





