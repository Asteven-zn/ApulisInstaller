#! /bin/sh

DOCKER_VER=19.03.13
ETCD_VER=v3.4.13
CNI_VER=v0.8.7
HELM_VER=v3.4.2
DOCKER_COMPOSE_VER=1.23.2
CRICTL_VER=v1.19.0
RUNC_VER=v1.0.0-rc92
CONTAINERD_VER=1.4.3
K8S_VER=v1.18.0

DEST=/tmp/extbins/arm64
mkdir -p $DEST

echo "Download docker-${DOCKER_VER}.tgz"
wget --tries=10 https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/static/stable/aarch64/docker-${DOCKER_VER}.tgz \
  || { echo "[ERROR] downloading docker-${DOCKER_VER}.tgz failed"; exit 1; }
mkdir tempbins && tar zxf docker-${DOCKER_VER}.tgz -C tempbins
mv ./tempbins/docker/* $DEST
rm -rf docker-${DOCKER_VER}.tgz ./tempbins

echo "\n\nDownload etcd-$ETCD_VER-linux-arm64.tar.gz"
wget --tries=10 https://github.com/etcd-io/etcd/releases/download/$ETCD_VER/etcd-$ETCD_VER-linux-arm64.tar.gz \
  || { echo "[ERROR] downloading etcd-$ETCD_VER-linux-arm64.tar.gz failed"; exit 1; }
tar zxf etcd-$ETCD_VER-linux-arm64.tar.gz
cd etcd-$ETCD_VER-linux-arm64 && mv etcd etcdctl $DEST && cd ..
rm -rf etcd-$ETCD_VER-linux-arm64*

echo "\n\nDownload cfssl arm64 tools"
wget --tries=10 https://pkg.cfssl.org/R1.2/cfssl_linux-arm \
  || { echo "[ERROR] downloading cfssl_linux-arm failed"; exit 1; }
wget --tries=10 https://pkg.cfssl.org/R1.2/cfssljson_linux-arm \
  || { echo "[ERROR] downloading cfssljson_linux-arm failed"; exit 1; }
wget --tries=10 https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-arm \
  || { echo "[ERROR] downloading cfssl-certinfo_linux-arm failed"; exit 1; }
mv cfssl_linux-arm $DEST/cfssl && chmod +x $DEST/cfssl
mv cfssljson_linux-arm $DEST/cfssljson && chmod +x $DEST/cfssljson
mv cfssl-certinfo_linux-arm $DEST/cfssl-certinfo && chmod +x $DEST/cfssl-certinfo

echo "\n\nDownloading cni-plugins-linux-arm64-$CNI_VER.tgz"
wget --tries=10 https://github.com/containernetworking/plugins/releases/download/$CNI_VER/cni-plugins-linux-arm64-$CNI_VER.tgz \
  || { echo "[ERROR] downloading cni-plugins-linux-arm64-$CNI_VER.tgz failed"; exit 1; }
mkdir tempbins && tar zxf cni-plugins-linux-arm64-$CNI_VER.tgz -C ./tempbins
cd ./tempbins &&  mv bridge flannel host-local loopback portmap tuning $DEST && cd ..
rm -rf cni-plugins-linux-arm64-$CNI_VER.tgz ./tempbins

echo "\n\nDownloading helm-$HELM_VER-linux-arm64.tar.gz"
wget --tries=10 https://get.helm.sh/helm-$HELM_VER-linux-arm64.tar.gz \
  || { echo "[ERROR] downloading helm-$HELM_VER-linux-arm64.tar.gz failed"; exit 1; }
tar zxf helm-$HELM_VER-linux-arm64.tar.gz
mv linux-arm64/helm $DEST
rm -rf linux-arm64 helm-$HELM_VER-linux-arm64.tar.gz

#echo "\n\nDownloading $DOCKER_COMPOSE_VER/docker-compose-Linux-x86_64"
#wget --tries=10 https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VER/docker-compose-Linux-x86_64 \
#  || { echo "[ERROR] downloading docker-compose-Linux-x86_64 failed"; exit 1; }
#mv docker-compose-Linux-x86_64 $DEST/docker-compose && chmod +x $DEST/docker-compose

echo "\n\nDownloading kubernetes-server-linux-arm64.tar.gz"
wget --tries=10 https://dl.k8s.io/$K8S_VER/kubernetes-server-linux-arm64.tar.gz \
  || { echo "[ERROR] downloading kubernetes-server-linux-arm64.tar.gz failed"; exit 1; }
tar zxf kubernetes-server-linux-arm64.tar.gz
cd kubernetes/server/bin \
  && mv kube-apiserver kube-controller-manager kube-scheduler $DEST \
  && mv kubelet kube-proxy kubectl $DEST \
  && cd ../../../
rm -rf kubernetes*