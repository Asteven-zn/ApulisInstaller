## Apulis AI Platform Installer

### 一.部署整体流程介绍

- 从github下载安装脚本

- 修改安装程序配置文件

- 执行安装程序

- 部署完成登录平台

  ***注意：服务器必须可以访问 Internet*
- 附GPU驱动安装


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

### 四.部署脚本

#### install.sh

```shell
#/bin/bash

#配置服务器的网卡ip地址
eth_ip=192.168.2.156


echo -e "\n-------------------------------prepare file----------------------------"
tar zxvf app.tar.gz -C /usr/local/bin/

mkdir -p /etc/docker
mkdir -p /root/.docker

echo -e "\n------------------------------stop firewalld---------------------------"
systemctl stop firewalld
systemctl disable firewalld
echo "ignore********************************"

echo -e "\n-------------------------------config iptables---------------------------"
iptables -P INPUT ACCEPT && iptables -F && iptables -X \
&& iptables -F -t nat && iptables -X -t nat \
&& iptables -F -t raw && iptables -X -t raw \
&& iptables -F -t mangle && iptables -X -t mangle

if [ $? -ne 0 ];then
        echo -e "config iptables failed"
else    
        echo -e "config iptables succeed"
        kubeclt get node
fi

echo -e "\n---------------------------check docker status----------------------------"

stat=`systemctl status docker | grep Active | awk -F " +" '{print $3}'`

if [ $stat = active ];then
        echo -e "docker is installed"
else
        echo -e "start install docker"
        bash docker.sh
fi

sleep 3

echo -e "\n-------------------------------check kubernetes status----------------------------"
stat=`systemctl status kubelet | grep Active | awk -F " +" '{print $3}'`

if [ $stat = active ];then
	echo -e "kubernetes is installed"
else
	echo -e "start install kubernetes"
        bash k8s.sh $eth_ip

fi

echo -e "\n-------------------------------check nfs status----------------------------"
stat=`systemctl status rpcbind | grep Active | awk -F " +" '{print $3}'`

if [ $stat = active ];then
        echo -e "nfs is installed"
else
        echo "start install nfs"
        bash nfs.sh
        showmount -e $eth_ip
fi

echo -e "\n-------------------------------running aiarts----------------------------"
if [[ ! -d "/etc/nginx/ssl" ]];then
    tar zxf nginxfile.tar.gz && mv ssl /etc/nginx/ && mv default.conf /etc/nginx/conf.other/
fi

cd build && bash apply.sh $eth_ip
```

### docker.sh

```shell
#!/bin/bash

echo -e "\n-------------------------------config docker file----------------------------"

cat <<EOF>/etc/docker/daemon.json
{
  "data-root": "/var/lib/docker",
  "exec-opts": ["native.cgroupdriver=cgroupfs"],
  "insecure-registries": ["127.0.0.1/8"],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "15m",
    "max-file": "3"
    },
  "storage-driver": "overlay2",
  "experimental": true
}
EOF 

cat <<EOF>/etc/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io

[Service]
Environment="PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStart=/usr/local/bin/dockerd 
ExecStartPost=/sbin/iptables -I FORWARD -s 0.0.0.0/0 -j ACCEPT
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

echo -e "\n-------------------------------start docker ----------------------------"
systemctl daemon-reload && systemctl enable docker.service && systemctl restart docker.service
```

#### k8s.sh

```shell
#!/bin/bash
#获取服务器ip
host_ip=$1

echo $host_ip

#安装k8s
echo -e "\n-------------------------------install kubernetes----------------------------"
apt-get update && apt-get install apt-transport-https -y

curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -

echo "deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list 

apt-get update

apt-get install -y kubelet=1.18.0-00 kubeadm=1.18.0-00 kubectl=1.18.0-00

kubeadm init  --apiserver-advertise-address=$host_ip \
        --image-repository=registry.aliyuncs.com/google_containers \
        --kubernetes-version=1.18.0 \
        --control-plane-endpoint="$host_ip:6443" \
        --service-cidr=10.68.0.0/16 \
        --pod-network-cidr=172.20.0.0/16 \
        --service-dns-domain=client.local

mkdir -p $HOME/.kube

sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

if [ $? -ne 0 ];then
        echo -e "*************************k8s install failed********************************"
else    
        echo -e "*************************k8s install succeed********************************"
        kubectl get node
fi

sleep 3

#节点打lable
echo -e "\n-------------------------------node lable tag----------------------------"
kubectl taint nodes --all node-role.kubernetes.io/master-
bash lab.sh
```

#### lab.sh

```shell
#!/bin/bash

kubectl get node --show-labels
lab=(
    "kubernetes.io/role=master"
    "FragmentGPUJob=active"
    "aiarts-backend=active"
    "aiarts-frontend=active"
    "alert-manager=active"
    "archType=amd64"
    "dataset-manager=active"
    "gpu=active"
    "gpuType=nvidia_gpu_amd64"
    "grafana=active"
    "image-label=active"
    "jobmanager=active"
    "mlflow=active"
    "nginx=active"
    "postgres=active"
    "prometheus=active"
    "restfulapi=active"
    "watchdog=active"
    "webportal=active"
    "webui=active"
    "worker=active"
);

length=${#lab}
#echo "长度为：$length"

# for 遍历
for item in ${lab[*]}
do
        #echo $item
        kubectl label nodes $HOSTNAME $item --overwrite
done
kubectl get node --show-labels
```

#### nfs.sh

```shell
#!/bin/bash

echo -e "\n-------------------------------install nfs----------------------------"

apt install nfs-common nfs-kernel-server -y

mkdir -p /data/nfs/pvc/aiplatform-label-data
mkdir -p /data/nfs/pvc/aiplatform-app-data
mkdir -p /data/nfs/pvc/aiplatform-component-data

cat <<EOF>/etc/exports
/data/nfs/pvc/aiplatform-label-data *(rw,sync,crossmnt,no_root_squash,no_subtree_check)
/data/nfs/pvc *(rw,sync,crossmnt,no_root_squash,no_subtree_check)
/data/nfs/pvc/aiplatform-app-data *(rw,sync,crossmnt,no_root_squash,no_subtree_check)
/data/nfs/pvc/aiplatform-component-data *(rw,sync,crossmnt,no_root_squash,no_subtree_check)
EOF

systemctl restart nfs-kernel-server
systemctl enable nfs-kernel-server

systemctl restart rpcbind
systemctl enable rpcbind
```

#### apply

```shell
#!/bin/bash

host_ip=$1

arr=(
    "storage-nfs"
    "nvidia-device-plugin"
    "postgres"
    "restfulapi2"
    "custom-user-dashboard"
    "jobmanager2"
    "custommetrics"
    "monitor"
    "nginx"
    "openresty"
    "webui3"
    "aiarts-backend"
    "aiarts-frontend"
    "mlflow"
    "volcanosh"
)

#修改环境ip
for item in ${arr[*]}
do
	#echo $item
	n=`cd $item && ls`
    old_ip=`grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' aiarts-backend/01.aiarts_cm.yaml | tail -1`
	#echo $n
    cd $item && for file in $n ; do ( sed -i s/$old_ip/$host_ip/g $file); done ; cd ../
	
done

#启动上次pod服务
length=${#arr}
#echo "长度为：$length"

# for 遍历服务目录
for item in ${arr[*]}
do
	#echo $item
	n=`cd $item && ls | grep '^[0-9]'`
	#echo $n
	cd $item && for file in $n ; do ( echo $file; kubectl apply -f $file ); done ; cd ../

done

cd istio && bash pre-render.sh && cd ../

sleep 3

arr2=(
    "knative"
    "kfserving"
    "cvat"
)

for item2 in ${arr3[*]}
do
	#echo $item
	n=`cd $item && ls | grep '^[0-9]'`
	#echo $n
	cd $item && for file in $n ; do ( echo $file; kubectl apply -f $file ); done ; cd ../

done

if [ $? -ne 0 ];then
        echo -e "*************************Apulis aiarts failed********************************"
else    
        echo -e "*************************Apulis aiarts succeed********************************"
fi
```

### 五.GPU驱动安装

```shell
查看设备gpu信息
lspci | grep -i nvidia
安装gpu驱动
apt install ubuntu-drivers-common -y
sudo ubuntu-drivers autoinstall -y

安装 nvidia-container-runtime
sed -i 's/127.0.0.53/8.8.8.8/' /etc/resolv.conf
curl -s -L https://nvidia.github.io/nvidia-container-runtime/gpgkey | sudo apt-key add - distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.list | sudo tee /etc/apt/sources.list.d/nvidia-container-runtime.list
sudo apt-get update
apt-get install nvidia-container-runtime -y
```

