#!/bin/bash

host_ip=$1

arr=(
    "volcanosh"
    "mlflow"
    "aiarts-frontend"
    "aiarts-backend"
    "webui3"
    "openresty"
    "nginx"
    "monitor"
    "custommetrics"
    "jobmanager2"
    "custom-user-dashboard"
    "restfulapi2"
    "postgres"
    "nvidia-device-plugin"
    "storage-nfs"
)

#cd istio && bash pre-render.sh && cd ../

sleep 3

arr2=(
    "cvat"
    "kfserving"
    "knative"
)

for item2 in ${arr3[*]}
do
	#echo $item
	n=`cd $item && ls | grep '^[0-9]'`
	#echo $n
	cd $item && for file in $n ; do ( echo $file; kubectl delete -f $file ); done ; cd ../

done

length=${#arr}
#echo "长度为：$length"

# for 遍历服务目录
for item in ${arr[*]}
do
	#echo $item
	n=`cd $item && ls | grep '^[0-9]'`
	#echo $n
	cd $item && for file in $n ; do ( echo $file; kubectl delete -f $file ); done ; cd ../

done

