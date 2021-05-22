#!/bin/bash

#host_ip=$1

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
        cd $item1 && for file in $n ; do ( sed -i s/conip/192.168.2.163/g $file); done ; cd ../
	
done

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

echo -e "\n-------------------------------------------------------------------------------------------------"
if [ $? -ne 0 ];then
    echo -e "Apulis AI Platform Installer failed"
else    
    echo -e "Apulis AI Platform Installer succeed"
    kubectl get node
fi
