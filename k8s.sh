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

#kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubectl apply -f calico.yaml

if [ $? -ne 0 ];then
        echo -e "*************************k8s install failed********************************"
else    
        echo -e "*************************k8s install succeed********************************"
        kubectl get node
fi

sleep 3

#kubectl 命令自动补全
echo "kubectl completion" >> ~/.bashrc
source <(kubectl completion bash)

#节点打lable
echo -e "\n-------------------------------node lable tag----------------------------"
kubectl label node $HOSTNAME node-role.kubernetes.io/worker=worker
kubectl taint nodes --all node-role.kubernetes.io/master-
bash lab.sh
