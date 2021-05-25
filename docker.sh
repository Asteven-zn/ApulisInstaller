#!/bin/bash

echo -e "\n-------------------------------config docker file----------------------------"

curl -s -L https://nvidia.github.io/nvidia-container-runtime/gpgkey | \
  sudo apt-key add -

distribution=$(. /etc/os-release;echo $ID$VERSION_ID)

curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-runtime.list
  
sudo apt-get update

apt-get install nvidia-container-runtime

echo -e "\n如果 nvidia-container-runtime 已安装会输出以上内容，请忽略********************************"

cp daemon.json /etc/docker/daemon.json

cat <<EOF>/etc/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io

[Service]
Environment="PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStart=/usr/local/bin/dockerd 
ExecStartPost=/sbin/iptables -I FORWARD -s 0.0.0.0/0 -j ACCEPT
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

echo -e "\n-------------------------------start docker ----------------------------"
systemctl daemon-reload && systemctl enable docker.service && systemctl restart docker.service