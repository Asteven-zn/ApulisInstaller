#!/bin/bash

cd build && bash applyrm.sh

kubeadm reset -f

rm -rf /etc/kubernetes/*.conf
rm -rf /etc/kubernetes/manifests/*.yaml

systemctl stop kubelet

systemctl disable docker.service && systemctl stop docker.service && systemctl daemon-reload

rm -rf /usr/local/bin/docker*
rm -rf /etc/docker
rm -rf /etc/systemd/system/docker.service