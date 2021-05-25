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