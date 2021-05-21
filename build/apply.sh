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

