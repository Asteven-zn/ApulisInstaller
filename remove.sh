#!/bin/bash

echo -e "\n-------------------------------uninstall Apulis AI Platform----------------------------"
cd build && bash applyrm.sh

echo -e "\n---------------------------------uninstall kubernetes----------------------------------"
kubeadm reset -f

rm -rf /etc/nginx
rm -rf /opt/kube
rm -rf /etc/kubernetes

systemctl stop kubelet

echo -e "\n-----------------------------------uninstall docker------------------------------------"
systemctl disable docker.service && systemctl stop docker.service && systemctl daemon-reload

echo -e "\n-------------------------------------delete file----------------------------------------"
rm -rf /usr/local/bin/
rm -rf /etc/docker
rm -rf /etc/systemd/system/docker.service
