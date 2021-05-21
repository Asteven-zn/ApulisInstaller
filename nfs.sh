#!/bin/bash

echo -e "\n-------------------------------install nfs----------------------------"

apt install nfs-common nfs-kernel-server -y

mkdir -p /data/nfs/pvc/aiplatform-label-data
mkdir -p /data/nfs/pvc/aiplatform-app-data
mkdir -p /data/nfs/pvc/aiplatform-component-data

cat <<EOF>/etc/exports
/data/nfs/pvc/aiplatform-label-data *(rw,sync,crossmnt,no_root_squash,no_subtree_check)
/data/nfs/pvc *(rw,sync,crossmnt,no_root_squash,no_subtree_check)
/data/nfs/pvc/aiplatform-app-data *(rw,sync,crossmnt,no_root_squash,no_subtree_check)
/data/nfs/pvc/aiplatform-component-data *(rw,sync,crossmnt,no_root_squash,no_subtree_check)
EOF

systemctl restart nfs-kernel-server
systemctl enable nfs-kernel-server

systemctl restart rpcbind
systemctl enable rpcbind