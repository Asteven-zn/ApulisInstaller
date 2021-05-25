#!/bin/bash

#host_ip=$1

echo -e "\n---------------------------down load docker image----------------------------"

image=(
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/custom-user-dashboard-backend:v1.5.0-rc8"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/dlworkspace_webui3:v1.5.0-rc8"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/dlworkspace_restfulapi2:v1.5.0-rc8"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/aiarts-frontend:v1.5.0-rc8"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/aiarts-backend:v1.5.0-rc7"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/dlworkspace_openresty:latest"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/custom-user-dashboard-frontend:v1.5.0-rc8"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/postgres:11.10-alpine"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/nginx:1.9"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/vc-webhook-manager:v0.0.1"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/vc-scheduler:v0.0.1"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/vc-controller-manager:v0.0.1"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/watchdog:1.9"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/grafana-zh:6.7.4"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/job-exporter:1.9"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/istio-proxy:latest"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/istio-pilot:latest"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/grafana:6.7.4"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/prom/prometheus:v2.18.0"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/directxman12/k8s-prometheus-adapter:v0.7.0"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/jessestuart/prometheus-operator:v0.38.0"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/redis:5.0.6-alpine"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/prom/node-exporter:v0.18.1"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/nvidia/k8s-device-plugin:1.11"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/busybox:v1.28"
)

for im in ${image[*]}
do
        #echo $im
        docker pull $im
done

echo -e "\n-------------------------------准备环境yaml文件----------------------------"

cp -r ../yaml/* ./

arr1=(
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
#    "mlflow"
    "volcanosh"
)

#修改环境ip
echo -e "\n-------------------------------配置环境IP----------------------------"
for item1 in ${arr1[*]}
do
	#echo $item1
	n=`cd $item1 && ls -l | grep ^- | awk -F " +" '{print $9}'`
        #old_ip=`grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' aiarts-backend/01.aiarts_cm.yaml | tail -1`
	#echo $n
        cd $item1 && for file in $n ; do ( sed -i s/conip/192.168.2.178/g $file); done ; cd ../
	
done

echo -e "\n---------------running Apulis check nfs status------------------------"
stat=`systemctl status rpcbind | grep Active | awk -F " +" '{print $3}'`

if [[ $stat = "active" ]];then
        echo -e "nfs is installed"
else
        echo "start install nfs"
        bash nfs.sh
        showmount -e $eth_ip
fi

#启动上层pod服务
echo -e "\n-------------------------------running Apulis AI Platform service ----------------------------"
#length=${#arr}
#echo "长度为：$length"

# for 遍历服务目录
for item1 in ${arr1[*]}
do
	#echo $item1
	n=`cd $item1 && ls | grep '^[0-9]'`
	#echo $n
	cd $item1 && for file in $n ; do ( echo $file; kubectl apply -f $file ); done ; cd ../

done

sleep 3

echo -e "\n-----------------------------------------running pre-render ------------------------------------"

cd istio && bash pre-render.sh && cd ../

arr2=(
    "knative"
    "kfserving"
#    "cvat"
)

for item2 in ${arr2[*]}
do
	#echo $item2
	n=`cd $item2 && ls | grep '^[0-9]'`
	#echo $n
	cd $item2 && for file in $n ; do ( echo $file; kubectl apply -f $file ); done ; cd ../
    
done

if [ $? -ne 0 ];then
    echo -e "\nApulis AI Platform Installer failed----------------------------------------------------------"
else    
    echo -e "\nApulis AI Platform Installer succeed---------------------------------------------------------"
    kubectl get node
fi
