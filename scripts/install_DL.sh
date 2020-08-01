#!/bin/bash

# Copyright 2020 Apulis Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

config_k8s_cluster() {
    ###### init kubernetes cluster config file
    IMAGE_DIR="${INSTALLED_DIR}/docker-images/${ARCH}"
    TEMP_CONFIG_NAME="temp.config"
    kubeadm config print init-defaults > $TEMP_CONFIG_NAME

    sed -i "s/clusterName.*/clusterName: ${CLUSTER_NAME}/g" $TEMP_CONFIG_NAME
    sed -i 's/.*kubernetesVersion.*/kubernetesVersion: v1.18.2/g' $TEMP_CONFIG_NAME
    sed -i "/dnsDomain/a\  podSubnet: \"10.244.0.0/16\"" $TEMP_CONFIG_NAME
    echo 'Please select a IP address and input'
    /sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v 172.17.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"

    echo 'Input target ip address:'
    read -r IP_ADDRESS
    echo $IP_ADDRESS
    sed -i "s/.*advertiseAddress.*/  advertiseAddress: $IP_ADDRESS/g" $TEMP_CONFIG_NAME
    cat $TEMP_CONFIG_NAME

    ###### init kubernetes cluster and save join command
    JOIN_COMMAND=`kubeadm init --config $TEMP_CONFIG_NAME | grep -A 1 kubeadm\ join`
    mkdir -p $HOME/.kube

    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    echo $JOIN_COMMAND > join-command
    sed -i 's/\\//g' join-command
}

install_dlws_admin_ubuntu () {
    useradd -d ${DLWS_HOME} -s /bin/bash dlwsadmin
    RC=$?
    case "$RC" in
	"0") echo "User created..."
	     echo "Set up default password 'dlwsadmin' ..."
	     echo "dlwsadmin:dlwsadmin" | chpasswd
	     break;
	     ;;
	"9") echo "User already exists..."
	     break;
	     ;;
	*)
	    echo "Can't create user. Will Exit..."
	    exit 2
	    ;;
    esac

    printf "Done to crate 'dlwsadmin'\n"

    mkdir -p ${DLWS_HOME}
    chown -R dlwsadmin:dlwsadmin ${DLWS_HOME}
    echo "dlwsadmin ALL = (root) NOPASSWD:ALL" | tee /etc/sudoers.d/dlwsadmin
    chmod 0440 /etc/sudoers.d/dlwsadmin
    sed -i s'/Defaults requiretty/#Defaults requiretty'/g /etc/sudoers
}

usage() {
    cat <<EOF
Usage: $0 [options] [command]
EOF
}

check_docker_installation() {
    ER=$(which docker)
    if [ x"${ER}" = "x" ]; then
	    printf "Docker Not Found. Will install later...\n"
	    NO_DOCKER=1
    else
	    printf "Docker Found at ${ER} \n"
	    NO_DOCKER=0
    fi

}

check_k8s_installation() {
    ER=$(which kubectl)
    if [ x"${ER}" = "x" ]; then
	    printf "kubectl Not Found. Will install later...\n"
	    NO_KUBECTL=1
    else
	    printf "kubectl Found at ${ER} \n"
	    NO_KUBECTL=0
    fi

    ER=$(which kubeadm)
    if [ x"${ER}" = "x" ]; then
	    printf "kubeadm Not Found. Will install later...\n"
	    NO_KUBEADM=1
    else
	    printf "kubeadm Found at ${ER} \n"
	    NO_KUBEADM=0
    fi

}


install_1st_necessary_packages () {
    PACKAGE_LIST="ssh build-essential python3.7 python3.7-dev python3-pip python3.7-venv apt-transport-https curl"
    if [ ${NO_DOCKER} = 1 ]; then
	PACKAGE_LIST="${PACKAGE_LIST} docker.io"
    fi

    set -x
    case "${INSTALL_OS}" in
	"ubuntu"|"linuxmint"|"debian")

	    ###### make sure no apt process
	    killall apt-get
	    killall dpkg
	    killall apt
	    dpkg --configure -a

	    apt-get update && apt-get install -y ${PACKAGE_LIST}
	    break;
	    ;;
	"centos"|"euleros")
	    ###### make sure no yum process
	    killall yum
	    killall rpm

	    exec yum update && yum install -y ${PACKAGE_LIST}
	    break;
	    ;;
	*)
	    printf "Not supported operating system: ${INSTALL_OS} \n";
	    printf "Exit...\n"
	    exit 2
    esac

    set +x

    if [ ${NO_KUBEADM} = 1 ] && [ ${NO_KUBECTL} = 1 ]; then
	    printf "Install Kubenetes components... \n"

	    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
	    cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
	    deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

	    k8s_version="1.18.0-00"

	    sudo apt-get update
	    sudo apt-get install -y kubelet kubeadm kubectl
	    #sudo apt-mark hold kubelet kubeadm kubectl

    else
	    printf "Kubectl and Kubeadm are already installed. Will confiure later...\n"
    fi



}



install_necessary_packages () {

    TEMP_DIR="/tmp/install_ytung_apt".${TIMESTAMP}
    mkdir -p ${TEMP_DIR}


    for entry in ${THIS_DIR}/apt/${ARCH}/*.deb
    do
        echo "$entry"
        filename=$(basename $entry)
        IFS='_' read -ra package <<< "$filename"

        INFO=$(dpkg -l ${package[0]} )
        RETURN_CODE=$?

        if [ ${RETURN_CODE} = 1 ]; then
	       echo "Looks like ${package[0]} has not been installed. Let's Install ...";
	       cp ${entry} $TEMP_DIR
        else
            INFO2=$(echo ${INFO##*$'\n'})
        	IFS=' ' read -ra detail <<< "$INFO2"
	        if [ ${detail[0]} = "ii" ] ; then
	            echo "Looks like ${package[0]} has been installed. Skip ...";
	        else
	            echo "Looks like ${package[0]} has not been installed yet. Let's Install ...";
	            cp $entry $TEMP_DIR
	        fi
        fi
    done

    dpkg -i ${TEMP_DIR}/*

    #### enable nfs server ###########################################
    systemctl enable nfs-kernel-server
}

install_source_dir () {

    if [ ! -f "${INSTALLED_DIR}" ]; then
	    mkdir -p ${INSTALLED_DIR}
    fi

    tar -xvf ./YTung.tar.gz -C ${INSTALLED_DIR} && echo "Source files extracted successfully!"

    (cd ${INSTALLED_DIR}; virtualenv --python=/usr/bin/python2.7 python2.7-venv)
    source ${INSTALLED_DIR}/python2.7-venv/bin/activate

    chown -R dlwsadmin:dlwsadmin ${INSTALLED_DIR}
}


set_up_password_less () {
    ID_DIR="${DLWS_HOME}/.ssh"

    echo "Test: ${ID_DIR}"
    if [ -f "${ID_DIR}" ]; then
	    printf "${ID_DIR} exists. \n"
    else
	    printf "Create Directory: ${ID_DIR} \n"
	    runuser dlwsadmin -c "mkdir ${DLWS_HOME}/.ssh"
    fi

    ID_FILE="${ID_DIR}/id_rsa"
    if [ -f "${ID_FILE}" ]; then
	    echo "User 'dlwsadmin' has set up the key. Set up the local passwordless access..."
    else
	    printf "Create SSH Key ...\n"
	    runuser dlwsadmin -c "ssh-keygen -t rsa -P '' -f ${ID_FILE}"
    fi

    runuser dlwsadmin -c "cat ${ID_DIR}/id_rsa.pub >> ${ID_DIR}/authorized_keys"

}


load_docker_images () {
    if [ ${COPY_DOCKER_IMAGE} = 1 ]; then
	    printf "Copy docker images from source\n"
	    DOCKER_IMAGE_DIRECTORY="${THIS_DIR}/docker-images/${ARCH}"

	    for file in ${DOCKER_IMAGE_DIRECTORY}/*.tar
	    do
	        printf "Load docker image file: $file\n"
	        docker load -i $file
	    done

    else
	    printf "Pull docker images from Docker Hub...\n"

	    ############ Will implement later ##################################

    fi
}

set_up_k8s_cluster () {
    echo "The Cluster Name will be set to: ${CLUSTER_NAME}"

    swapoff -a
    sed -i '/[ \t]swap[ \t]/ s/^\(.*\)$/#\1/g' /etc/fstab
}

setup_user_on_node() {

    local node=$1

    if [ x"${SUDO_USER}" != "x" ]; then
	node=${SUDO_USER}@$node
    fi
    echo "Node is: ", ${node}
    ssh -t ${node}  "(sudo useradd -d ${DLWS_HOME} -s /bin/bash dlwsadmin; echo \"dlwsadmin:dlwsadmin\" | sudo chpasswd ; \\
sudo mkdir -p ${DLWS_HOME}; sudo mkdir -p ${DLWS_HOME}/.ssh && sudo chown -R dlwsadmin:dlwsadmin ${DLWS_HOME}) && sudo runuser dlwsadmin -c \"ssh-keygen -t rsa -P '' -f ${DLWS_HOME}/.ssh/id_rsa\" \\
&& echo \"dlwsadmin ALL = (root) NOPASSWD:ALL\" | sudo tee /etc/sudoers.d/dlwsadmin && sudo chmod 0440 /etc/sudoers.d/dlwsadmin && sudo sed -i s'/Defaults requiretty/#Defaults requiretty'/g /etc/sudoers  "

    return $?

}

create_nfs_share() {

    mkdir -p $NFS_MOUNT_POINT

    if [ $EXTERNAL_NFS_MOUNT = 0 ]; then
        chown -R nobody:nogroup $NFS_MOUNT_POINT
        chmod 777 $NFS_MOUNT_POINT

        ############ /etc/exports will only open to the nodes client. ###############################################
        for worknode in "${nodes[@]}"
        do
           echo "$NFS_MOUNT_POINT  $worknode   (re,sync,no_subtree_check)" | tee -a /etc/exports
        done

        exportfs -a
        systemctl restart nfs-kernel-server
    else
        echo "${EXTERNAL_MOUNT_POINT}          ${NFS_MOUNT_POINT}    nfs        auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0 " | tee -a /etc/fstab
        mount ${EXTERNAL_MOUNT_POINT}          ${NFS_MOUNT_POINT}
    fi
}


###### generate config.yaml ####################################################################
generate_config() {

    # get host ip as master
    master_hostname=`hostname`
    master_ip=`grep "${master_hostname}" /etc/hosts | grep -v 127 | grep -v ${master_hostname}\. | awk '{print $1}'`

    # write basic info
    cat << EOF > config.yaml
cluster_name: DLWorkspace

network:
  domain: sigsus.cn
  container-network-iprange: "10.0.0.0/8"

etcd_node_num: 1
mounthomefolder : True
kubepresleep: 1

datasource: MySQL
mysql_password: apulis#2019#wednesday
webuiport: 3081
useclusterfile : true

admin_username: dlwsadmin

# settings for docker
private_docker_registry: harbor.sigsus.cn/library/
dockerregistry: apulistech/
dockers:
  hub: apulistech/
  tag: "1.9"

custom_mounts: []
admin_username: dlwsadmin

custom_mounts: []
data-disk: /dev/[sh]d[^a]
dataFolderAccessPoint: ''

datasource: MySQL
defalt_virtual_cluster_name: platform
default-storage-folders:
- jobfiles
- storage
- work
- namenodeshare

deploymounts: []

discoverserver: 4.2.2.1
dltsdata-atorage-mount-path: /dltsdata
dns_server:
  azure_cluster: 8.8.8.8
  onpremise: 10.50.10.50

Authentications:
  Wechat:
    AppId: "wx403e175ad2bf1d2d"
    AppSecret: "dc8cb2946b1d8fe6256d49d63cd776d0"

supported_platform:  ["onpremise"]
onpremise_cluster:
  worker_node_num:    1
  gpu_count_per_node: 1
  gpu_type:           nvidia

mountpoints:
  nfsshare1:
    type: nfs
    server: master
    filesharename: /mnt/local
    curphysicalmountpoint: /mntdlws
    mountpoints: ""

jwt:
  secret_key: "Sign key for JWT"
  algorithm: HS256
  token_ttl: 86400

k8sAPIport: 6443
k8s-gitbranch: v1.18.2
deploy_method: kubeadm

enable_custom_registry_secrets: True

WebUIadminGroups:
    - DLWSAdmins

WebUIauthorizedGroups:
    - DLWSAdmins

WebUIregisterGroups:
    - DLWSRegister

UserGroups:
  DLWSAdmins:
    Allowed:
    - jinlmsft@hotmail.com
    - jinli.ccs@gmail.com
    - jin.li@apulis.com
    gid: "20001"
    uid: "20000"
  DLWSRegister:
    Allowed:
    - '@gmail.com'
    - '@live.com'
    - '@outlook.com'
    - '@hotmail.com'
    - '@apulis.com'
    gid: "20001"
    uid: 20001-29999

repair-manager:
  cluster_name: "DLWorkspace"
  ecc_rule:
    cordon_dry_run: True
  alert:
    smtp_url: smtp.qq.com
    login: 1023950387@qq.com
    password: vtguxryxqyrkbfdd
    sender: 1023950387@qq.com
    receiver: ["1023950387@qq.com"]

machines:
  ${master_hostname}:
    role: infrastructure
    private-ip: ${master_ip}
    archtype: amd64
    type: cpu
EOF

   # write worker nodes info
for worknode in "${nodes[@]}"
do
   cat << EOF >> config.yaml

  ${worknode}:
    role: worker
    archtype: amd64
    type: gpu
    vendor: nvidia
    os: ubuntu

EOF
done

cat << EOF >> config.yaml

extranet_protocol: http

EOF

}

############################################################################
#
#   MAIN CODE START FROM HERE
#
############################################################################
DLWS_HOME="/home/dlwsadmin"
NO_DOCKER=1
NO_KUBECTL=1
NO_KUBEADM=1
NVIDIA_CUDA=0
HUAWEI_NPU="False"
COPY_DOCKER_IMAGE=1
DOCKER_REGISTRY=
INSTALLED_DIR="/home/dlwsadmin/DLWorkspace"
NO_NFS=1
EXTERNAL_NFS_MOUNT=0
EXTERNAL_MOUNT_POINT=
NFS_MOUNT_POINT="/mnt/nfs_share"
USE_MASTER_NODE_AS_WORKER=1

CLUSTER_NAME="DLWorkspace"


############# Don't source the install file. Run it in sh or bash ##########
if ! echo "$0" | grep '\.sh$' > /dev/null; then
    printf 'Please run using "bash" or "sh", but not "." or "source"\\n' >&2
    return 1
fi


############ Check CPU Aritecchure ########################################
ARCH=$(uname -m)
printf "Hardware Architecture: ${ARCH}\n"

###########  Check Operation System ######################################
INSTALL_OS=$(grep '^ID=' /etc/os-release | awk -F'=' '{print $2}')
OS_RELEASE=$(grep '^VERSION_ID=' /etc/os-release | awk -F'=' '{print $2}')

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
THIS_FILE=$(basename "$0")
THIS_PATH="$THIS_DIR/$THIS_FILE"

USAGE="
usage: $0 [options]

Installs YTung AI Workspace 2020.06

-d           install directory. Default:  "/home/dlwsadmin/DLWorkspace"
-n           install cluster name. Default: "DLWorkspace"
-u           install A910 device plugin. Default: False
-r           remote docker registry
-f           load docker images from local. Default: True

-h	     print usage page.
"

if which getopt > /dev/null 2>&1; then
    OPTS=$(getopt d:n:r:m:ulhez "$*" 2>/dev/null)
    if [ ! $? ]; then
        printf "%s\\n" "$USAGE"
        exit 2
    fi

    eval set -- "$OPTS"

    while true; do
        case "$1" in
            -h)
                printf "%s\\n" "$USAGE"
                exit 2
                ;;
	        -d)
		        INSTALLED_DIR="$2"
		        shift;
		        shift;
		        ;;
	        -n)
		        CLUSTER_NAME="$2"
		        shift;
		        shift;
		        ;;
	        -u)
		        HUAWEI_NPU=1
		        shift;
		        ;;
	        -f)
		        COPY_DOCKER_IMAGE=1
		        shift;
		        ;;
	        -r)
		        COPY_DOCKER_IMAGE=0
		        DOCKER_REGISTRY="$2"
		        shift;
		        shift;
		        ;;
	        -e)
		        EXTERNAL_NFS_MOUNT=1
		        EXTERNAL_MOUNT_POINT="$2"
		        shift;
		        shift;
		        ;;
		    -m)
		        NFS_MOUNT_POINT="$2"
		        shift;
		        shift;
		        ;;
		    -z)
		        NO_NFS=0
		        shift;
		        ;;
	        --)
                shift
                break
                ;;
            *)
                printf "ERROR: did not recognize option '%s', please try -h\\n" "$1"
                exit 1
                ;;

	    esac
    done
fi


printf "directory: ${THIS_DIR} file: ${THIS_FILE} path: ${THIS_PATH} \n"
printf "system: ${INSTALL_OS} version: ${OS_RELEASE} \n"


printf "Install directory: $INSTALLED_DIR \n"
printf "Cluster Name:  $CLUSTER_NAME \n"


########### Assume install is interactive (Can change later) #############
BATCH=0

########### First of all, check if you have root privilleges #############
RUN_USER=$(ps -p $$ -o ruser=)

if [ "${RUN_USER}" != "root" ]; then
    printf "ERROR: \n"
    printf "      You run as user: ${RUN_USER}. We need root privillege to install DLWorkspace\n"
    exit 2
fi


if [ "$BATCH" = "0" ] # interactive mode
then
    if [ "${ARCH}" != "x86_64" ] && [ "${ARCH}" != "aarch64" ]; then
        printf "ERROR:\\n"
        printf "    Your hardware is not x86_64 or aarch64 (${ARCH})\\n"
        printf "Aborting installation\\n"
        exit 2
    fi
    if [ "$(uname)" != "Linux" ]; then
        printf "WARNING:\\n"
        printf "    Your operating system does not appear to be Linux, \\n"
        printf "    But you are trying to install a Linux version of DLWorkspace\\n"
        printf "Aborting installation\\n"
        exit 2
    fi
fi

    printf "\\n"
    printf "Welcome to DLWorkspace 2020.06\\n"
    printf "\\n"
    printf "In order to continue the installation process, please review the license\\n"
    printf "agreement.\\n"
    printf "Please, press ENTER to continue\\n"
    printf ">>> "
    read -r dummy
    pager="cat"
    if command -v "more" > /dev/null 2>&1; then
      pager="more"
    fi
    "$pager" <<EOF
===================================
End User License Agreement - Apulis

请务必仔细阅读和理解此Apulis Platform软件最终用户许可协议（“本《协议》”）中规定的所有权利和限制。
在安装本“软件”时，您需要仔细阅读并决定接受或不接受本《协议》的条款。除非或直至您接受本《协议》的全
部条款，否则您不得将本“软件”安装在任何计算机上。本《协议》是您与依瞳科技之间有关本“软件”的法律协议。
本“软件”包括随附的计算机软件，并可能包括计算机软件相关载体、相关文档电子或印刷材料。除非另附单独的
最终用户许可协议或使用条件说明，否则本“软件”还包括在您获得本“软件”后由依瞳科技不时有选择所提供的任
何本“软件”升级版本、修正程序、修订、附加成分和补充内容。您一旦安装本“软件”，即表示您同意接受本《协
议》各项条款的约束。如您不同意本《协议》中的条款，您则不可以安装或使用本“软件”。

本“软件”受中华人民共和国著作权法及国际著作权条约和其它知识产权法和条约的保护。本“软件”权利只许可使
用，而不出售。

至此，您肯定已经详细阅读并已理解本《协议》，并同意严格遵守各条款和条件。
===================================

Copyright 2019-2020, Apulis, Inc.

All rights reserved under the MIT License:
EOF

    printf "\\n"
    printf "Do you accept the license terms? [yes|no]\\n"
    printf "[no] >>> "
    read -r ans
    while [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
          [ "$ans" != "no" ]  && [ "$ans" != "No" ]  && [ "$ans" != "NO" ]
    do
        printf "Please answer 'yes' or 'no':'\\n"
        printf ">>> "
        read -r ans
    done
    if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ]
    then
        printf "The license agreement wasn't approved, aborting installation.\\n"
        exit 2
    fi

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!"
echo "!   Start to work on the master. Hostname is: " $(hostname)
echo "!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

TIMESTAMP=$(date "+%Y%m%d-%H:%M:%S")

if [ "${INSTALL_OS}" = "ubuntu" ] ||  [ "${INSTALL_OS}" = "linuxmint" ] ;
then
    printf "Install DLWS On Ubuntu...\n"
    if [ "${OS_RELEASE}" != "18.04" ]; then
	    printf "WARNING: \n"
	    printf "       DLWorkspace is only certified on 18.04, 19.04, 19.10\n"
    fi


    check_docker_installation
    check_k8s_installation

    #install_1st_necessary_packages
    install_necessary_packages

    install_dlws_admin_ubuntu

    set_up_password_less

    #### set up DLWorkspace source tree ####################################
    install_source_dir && echo "Successfully installed source tree..."

    #### check if there are nVidia Cards ###################################
    #${INSTALLED_DIR}/src/ClusterBootstrap/scripts/prepare_ubuntu.sh

    #### load/copy docker images ###########################################
    usermod -a -G docker dlwsadmin     # Add dlwsadmin to docker group

    load_docker_images

    #### copy config ###########################################
    TEMP_CONFIG_DIR=${INSTALLED_DIR}/temp-config
    mkdir -p $TEMP_CONFIG_DIR
    cp -r config/* $TEMP_CONFIG_DIR

    #### check if A910 is presented ########################################
    if [ -f "/dev/davinci0" ] && [ -f "/dev/davinci_manager" ] && [ -f "/dev/hisi_hdc" ]; then
	    echo "Load A910 device plugin images ..."
	    if [ ${COPY_DOCKER_IMAGE} = 1 ]; then
	        gzip "${INSTALLED_DIR}/docker-images/A910_driver/${ARCH}/device-plugin.tar.gz" | docker load
	    else
	        echo "Build Device Plugin images ..."
	        # docker build ...
	    fi
    fi

    #### Now, this is basic setting of K8s services ####################
    set_up_k8s_cluster
    #config_k8s_cluster

fi

#################### Now, deploy node #########################################################################

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!"
echo "!   Start to work on node. "
echo "!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

printf "\\n"
printf "Do you want to use master as worknode? [yes|no] \\n"
printf "[no] >>> "

  read -r ans
  while [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
        [ "$ans" != "no" ]  && [ "$ans" != "No" ]  && [ "$ans" != "NO" ]
  do
      printf "Please answer 'yes' or 'no':'\\n"
      printf ">>> "
      read -r ans
  done

if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ]
  then
    printf "Not setup Up Master as a worknode.\\n"

    USE_MASTER_NODE_AS_WORKER=0
fi


declare -a nodes=()
node_number=1

while [ ${node_number} -le 5 ]
do
    printf "\\n"
    printf "Add More Node in the cluster"
    printf "\\n"
    printf "Please enter quit and finish setting hostname \\n"
    printf "Or enter the hostname of node (Node Number: ${node_number} ). \\n"
    printf ">>> "
    read -r nodename
    if [ $nodename = "quit" ]; then
        printf "No more node is need to set up. \\n"
        break;
    else
        printf "Set up node ...\\n"
        setup_user_on_node $nodename
        if [ $? = 0 ]; then
            nodes[ $(( ${node_number} - 1 )) ]=${nodename}
            node_number=$(( ${node_number} + 1 ))
        fi
    fi
done

echo ${nodes[@]}
printf "Total number of nodes: ${#nodes[@]} \\n"

########### setting up for master, also copy the package files and docker images files ###########################################
REMOTE_INSTALL_DIR="/tmp/install_YTung.$TIMESTAMP"
REMOTE_APT_DIR="${REMOTE_INSTALL_DIR}/apt/${ARCH}"
REMOTE_IMAGE_DIR="${REMOTE_INSTALL_DIR}/docker-images/${ARCH}"
REMOTE_CONFIG_DIR="${REMOTE_INSTALL_DIR}/config"
REMOTE_PYTHON_DIR="${REMOTE_INSTALL_DIR}/python2.7"

runuser dlwsadmin -c "ssh-keyscan ${nodes[@]} >> ~/.ssh/known_hosts"

############# Create NFS share ###################################################################
if [ ${NO_NFS} = 0 ]; then
   create_nfs_share
fi

for worknode in "${nodes[@]}"
do
    ######### set up passwordless access from Master to Node ################################
    cat ~dlwsadmin/.ssh/id_rsa.pub | sshpass -p dlwsadmin ssh dlwsadmin@$worknode 'cat >> .ssh/authorized_keys'
    ######### set up passwordless access from Node to Master ################################
    sshpass -p dlwsadmin ssh dlwsadmin@$worknode cat ~dlwsadmin/.ssh/id_rsa.pub | cat >> ~dlwsadmin/.ssh/authorized_keys

    sshpass -p dlwsadmin ssh dlwsadmin@$worknode "mkdir -p ${REMOTE_INSTALL_DIR}; mkdir -p ${REMOTE_IMAGE_DIR}; mkdir -p ${REMOTE_APT_DIR}; mkdir -p ${REMOTE_CONFIG_DIR}; mkdir -p ${REMOTE_PYTHON_DIR}"

    sshpass -p dlwsadmin scp apt/${ARCH}/*.deb dlwsadmin@$worknode:${REMOTE_APT_DIR}

    sshpass -p dlwsadmin scp docker-images/${ARCH}/* dlwsadmin@$worknode:${REMOTE_IMAGE_DIR}


    sshpass -p dlwsadmin scp install_worknode.sh dlwsadmin@$worknode:${REMOTE_INSTALL_DIR}

    #sshpass -p dlwsadmin scp join-command dlwsadmin@$worknode:${REMOTE_INSTALL_DIR}

    sshpass -p dlwsadmin scp YTung.tar.gz dlwsadmin@$worknode:${REMOTE_INSTALL_DIR}

    sshpass -p dlwsadmin scp python2.7/* dlwsadmin@$worknode:${REMOTE_INSTALL_DIR}/python2.7

    ########################### Install on remote node ######################################
    sshpass -p dlwsadmin ssh dlwsadmin@$worknode "cd ${REMOTE_INSTALL_DIR}; sudo bash ./install_worknode.sh | tee /tmp/installation.log.$TIMESTAMP"

    #### enable nfs server ###########################################
    sshpass -p dlwsadmin ssh dlwsadmin@$worknode "sudo systemctl enable nfs-kernel-server"

    if [ ${NO_NFS} = 0 ]; then
       if [ $EXTERNAL_NFS_MOUNT = 0 ]; then
           EXTERNAL_MOUNT_POINT="$(hostname -I | awk '{print $1}'):${NFS_MOUNT_POINT}"
       fi
       sshpass -p dlwsadmin ssh dlwsadmin@$worknode "echo \"${EXTERNAL_MOUNT_POINT}          ${NFS_MOUNT_POINT}    nfs   auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0 \" | sudo tee -a /etc/fstab ; sudo mount ${EXTERNAL_MOUNT_POINT}  ${NFS_MOUNT_POINT}"
    fi

done

###### apply weave network ###################################################################
# kubectl apply -f config/weave-net.yaml # don't apply on command, deploy.py will handle the job

source ${INSTALLED_DIR}/python2.7-venv/bin/activate

###### deploy with deploy.py ###################################################################
cd ${INSTALLED_DIR}/YTung/src/ClusterBootstrap # enter into deploy.py directory


###### start building cluster ####################################################################
generate_config

./deploy.py --verbose -y build

mkdir -p deploy/sshkey
cd deploy/sshkey

echo "dlwsadmin" > "rootuser"
echo "dlwsadmin" > "rootpasswd"
cd ../..

./deploy.py --verbose sshkey install

mkdir -p ./deploy/etc
cp /etc/hosts ./deploy/etc/hosts
./deploy.py --verbose copytoall ./deploy/etc/hosts  /etc/hosts

./deploy.py --verbose kubeadm init
./deploy.py --verbose copytoall ./deploy/sshkey/admin.conf /root/.kube/config

if [ ${USE_MASTER_NODE_AS_WORKER} = 1 ]; then
    ./deploy.py --verbose kubernetes uncordon
fi

./deploy.py --verbose kubeadm join
./deploy.py --verbose -y kubernetes labelservice
./deploy.py --verbose -y labelworker

./deploy.py --verbose kubernetes start nvidia-device-plugin

./deploy.py --verbose renderservice
./deploy.py --verbose renderimage
./deploy.py --verbose webui
./deploy.py --verbose nginx webui3

./deploy.py --verbose nginx fqdn
./deploy.py --verbose nginx config

./deploy.py --verbose kubernetes start mysql
./deploy.py --verbose kubernetes start jobmanager2 restfulapi2 monitor nginx custommetrics repairmanager2 openresty
./deploy.py --verbose kubernetes start monitor

./deploy.py --verbose kubernetes start webui3
./deploy.py kubernetes start custom-user-dashboard
