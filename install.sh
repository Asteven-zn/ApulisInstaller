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

stat=`kubectl get pod -n kube-system | grep calico | wc -l`

if [ $stat = 2 ];then
        cd build && bash apply.sh $eth_ip
else
        echo "calico network is no ready"
fi

