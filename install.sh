#/bin/bash

#配置服务器的网卡ip地址
eth_ip=192.168.2.163

#准备工作
echo -e "\n-------------------------------prepare file----------------------------"
tar zxvf app.tar.gz -C /usr/local/bin/

mkdir -p /etc/docker
mkdir -p /root/.docker

oldip=`grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' build/apply.sh`
sed -i s/$oldip/$eth_ip/g build/apply.sh

echo -e "\n------------------------------stop firewalld---------------------------"
systemctl stop firewalld
systemctl disable firewalld
echo "ignore********************************"
swapoff -a && sysctl -w vm.swappiness=0
sed -ri 's/.*swap.*/#&/' /etc/fstab

echo -e "\n-------------------------------config iptables---------------------------"
iptables -P INPUT ACCEPT && iptables -F && iptables -X \
&& iptables -F -t nat && iptables -X -t nat \
&& iptables -F -t raw && iptables -X -t raw \
&& iptables -F -t mangle && iptables -X -t mangle

if [ $? -ne 0 ];then
        echo -e "config iptables failed"
else    
        echo -e "config iptables succeed"
fi

#部署docker
echo -e "\n---------------------------check docker status----------------------------"

stat=`systemctl status docker | grep Active | awk -F " +" '{print $3}'`

if [ $stat = active ];then
        echo -e "docker is installed"
else
        echo -e "start install docker"
        bash docker.sh
fi

sleep 3

#部署kubernetes
echo -e "\n-------------------------------check kubernetes status----------------------------"
stat=`systemctl status kubelet | grep Active | awk -F " +" '{print $3}'`

if [ $stat = active ];then
	echo -e "kubernetes is installed"
else
	echo -e "start install kubernetes"
        bash k8s.sh $eth_ip

fi

sleep 10

#部署nfs存储
echo -e "\n-------------------------------check nfs status----------------------------"
stat=`systemctl status rpcbind | grep Active | awk -F " +" '{print $3}'`

if [ $stat = active ];then
        echo -e "nfs is installed"
else
        echo "start install nfs"
        bash nfs.sh
        showmount -e $eth_ip
fi

#部署Apulis AI Platform
echo -e "\n-------------------------------install Apulis AI Platform----------------------------"
if [[ ! -d "/etc/nginx/ssl" ]];then
    mkdir -p /etc/nginx/conf.other
    tar zxf nginxfile.tar.gz && mv ssl /etc/nginx/ && mv default.conf /etc/nginx/conf.other/
fi

stat=`kubectl get pod -n kube-system | grep calico | wc -l`

if [ $stat = 2 ];then
        cd build && bash apply.sh $eth_ip
else
        echo "calico network is no ready"
fi
