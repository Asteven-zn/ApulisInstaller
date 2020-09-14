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

#set -x

input_harbor_library_name() {
	reset_library_name="no"
	printf "harbor name has been set to :%s \naccept it?[(default)yes/no]:" "$DOCKER_HARBOR_LIBRARY"
	read -r ans
	while [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && [ "$ans" != "" ] && \
			[ "$ans" != "no" ]  && [ "$ans" != "No" ]  && [ "$ans" != "NO" ]
	do
		printf "Please answer 'yes(default)' or 'no':'\\n"
		printf ">>> "
		read -r ans
	done
	if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && [ "$ans" != "" ]; then
		reset_library_name="yes"
	fi
	if [ "$reset_library_name" == "yes" ]
	then
		ans="no"
		while [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ]
		do
			printf "Please input your library name >>> "
			read -r DOCKER_HARBOR_LIBRARY
			while [ "$DOCKER_HARBOR_LIBRARY" != "" ]
			do
				printf "!! Docker harbor name can't be empty !! Please reinput >>>"
				read -r DOCKER_HARBOR_LIBRARY
			done
			printf "Your library name is \"${DOCKER_HARBOR_LIBRARY}\", is that correct?"
			printf "[yes/no] >>> "

			read -r ans
			while [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
					[ "$ans" != "no" ]  && [ "$ans" != "No" ]  && [ "$ans" != "NO" ]
			do
				printf "Please answer 'yes' or 'no':'\\n"
				printf ">>> "
				read -r ans
			done
		done
	fi
    printf "library selected set as >>>${DOCKER_HARBOR_LIBRARY}."
    printf "now continue.\n"
}
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

    cp ${THIS_DIR}/apt/${ARCH}/libseccomp2_2.4.3-1ubuntu3.18.04.3_${ARCHTYPE}.deb ${TEMP_DIR}/

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

    dpkg -i ${TEMP_DIR}/libseccomp2_2.4.3-1ubuntu3.18.04.3_${ARCHTYPE}.deb # fix 18.04.1 docker deps
    dpkg -i ${TEMP_DIR}/*

    #### enable nfs server ###########################################
    systemctl enable nfs-kernel-server
}

copy_bin_file (){
  DIS_DIR="/usr/bin/"
  for entry in ${THIS_DIR}/bin/${ARCH}/*
  do
      echo "$entry"
      if [ -f $$entry ];then
        IS_EXIST=1
      fi

      if [ ${IS_EXIST} = 0 ]; then
        echo "Looks like $entry has not been copy. Let's copy ...";
        cp ${entry} $DIS_DIR
      else
        echo "Looks like ${package[0]} has been copy. Skip ...";
      fi
  done
}

prepare_nfs_storage_path () {
#	reset_nfs_path="no"
#	if [ "$NFS_STORAGE_PATH" != "/mnt/local"]
#	then
#		printf "nfs storage has been set to :%s \naccept it?[(default)yes/no]:" "$NFS_STORAGE_PATH"
#		read -r ans
#		while [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && [ "$ans" != "" ] && \
#				[ "$ans" != "no" ]  && [ "$ans" != "No" ]  && [ "$ans" != "NO" ]
#		do
#			printf "Please answer 'yes(default)' or 'no':'\\n"
#			printf ">>> "
#			read -r ans
#		done
#		if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && [ "$ans" != "" ]; then
#			reset_nfs_path="yes"
#		fi
#	else
#		printf "\n!!!!Your nfs storage path has been set to /mnt/local, which is not allowed. Please reset.!!!!\n"
#		reset_nfs_path="yes"
#	fi
#	if [ "$reset_nfs_path" == "yes" ]
#	then
#		echo 'Please input nfs storage path: (Path of current machine. Please ensure the dir disk is big enough. Do NOT use /mnt/local)'
#		echo '[e.g. /mnt/disk]'
#		read -r NFS_STORAGE_PATH
#		if [ -d "$NFS_STORAGE_PATH" ]; then
#		  echo "$NFS_STORAGE_PATH exists"
#		else
#		  echo "$NFS_STORAGE_PATH not exists"
#		  exit 1
#		fi
#	fi

    NFS_DIR=/mnt/local
    mkdir -p /mnt
    rm -rf $NFS_DIR
    ln -s $NFS_STORAGE_PATH $NFS_DIR
    echo 'NFS prepared success'
}

install_harbor () {

    HARBOR_DIR=/data/harbor
    mkdir -p /data
    rm -rf $HARBOR_DIR
    ln -s $HARBOR_STORAGE_PATH $HARBOR_DIR

    #### install docker-compose
    echo "Installing docker-compose ..."
    chmod +x ${THIS_DIR}/harbor/docker-compose
    cp ${THIS_DIR}/harbor/docker-compose /usr/bin/docker-compose

    #### prepare harbor
    echo "Preparing harbor ..."
    HARBOR_INSTALL_DIR="/opt"
    mkdir -p ${HARBOR_INSTALL_DIR}
    tar -zxvf ${THIS_DIR}/harbor/harbor.tgz -C $HARBOR_INSTALL_DIR
    cp ${THIS_DIR}/config/harbor/harbor.yml $HARBOR_INSTALL_DIR/harbor/
    sed -i "s/\${admin_password}/$HARBOR_ADMIN_PASSWORD/" $HARBOR_INSTALL_DIR/harbor/harbor.yml
    echo "Preparing docker certs, docker daemon will restart soon ..."
    mkdir -p $HARBOR_INSTALL_DIR/harbor/cert
    cp -r ${THIS_DIR}/config/harbor/harbor-cert/* $HARBOR_INSTALL_DIR/harbor/cert/
    mkdir -p /etc/docker/certs.d
    cp -r ${THIS_DIR}/config/harbor/docker-certs.d/* /etc/docker/certs.d/
    systemctl restart docker

    #### install harbor
    echo "Installing harbor ..."
    $HARBOR_INSTALL_DIR/harbor/install.sh
    sleep 10
    echo "Docker login harbor ..."
    docker login ${HARBOR_REGISTRY}:8443 -u admin -p ${HARBOR_ADMIN_PASSWORD} || handle_docker_login_fail
   echo "Check if docker login success ..."
    echo "[y/n]>>>"
    read -r ans
    if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ]; then
      echo "Ensure docker login success, continue ..."
    else
      echo "Please check docker harbor problems"
      exit 2
    fi

    #### create basic harbor library
    curl -X POST "https://${HARBOR_REGISTRY}:8443/api/v2.0/projects" -H 'Content-Type: application/json' -k -u admin:${HARBOR_ADMIN_PASSWORD} --data-raw "
    {
      \"project_name\": \"${DOCKER_HARBOR_LIBRARY}\",
      \"metadata\": {
        \"public\": \"true\"
      },
      \"storage_limit\": -1
    }"
}

handle_docker_login_fail() {
	printf "!!!!docker auto login fail!!!!"
	printf "continue process? [y/n(default)] >>>"
	read -r ans
	while [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && [ "$ans" != "" ] && [ "$ans" != "y" ] && \
			[ "$ans" != "no" ]  && [ "$ans" != "No" ]  && [ "$ans" != "NO" ] && [ "$ans" != "n" ] 
	do
		printf "Please answer 'y' or 'n':'\\n"
		printf ">>> "
		read -r ans
	done
	if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && [ "$ans" != "y" ]; then
		printf "OK. relauch when everything is reaady"
		exit
	fi
	printf "Continue."
}

install_source_dir () {

    if [ ! -f "${INSTALLED_DIR}" ]; then
	    mkdir -p ${INSTALLED_DIR}
    fi

    tar -xvf ./YTung.tar.gz -C ${INSTALLED_DIR} && echo "Source files extracted successfully!"

    (cd python2.7/${ARCH}; pip install setuptools* ;pip install wheel*; python setup.py bdist_wheel;pip install ./*;tar -xf PyYAML*.tar.gz -C ${INSTALLED_DIR})
    (cd ${INSTALLED_DIR}/PyYAML*; python setup.py install )

    (cd ${INSTALLED_DIR}; virtualenv --python=/usr/bin/python2.7 python2.7-venv)
    source ${INSTALLED_DIR}/python2.7-venv/bin/activate

    (cd python2.7/${ARCH}; pip install setuptools* ;pip install wheel*; python setup.py bdist_wheel;pip install ./*; tar -xf PyYAML*.tar.gz -C ${INSTALLED_DIR})
    (cd ${INSTALLED_DIR}/PyYAML*; python setup.py install )

    chown -R dlwsadmin:dlwsadmin ${INSTALLED_DIR}

    TEMP_CONFIG_DIR=${INSTALLED_DIR}/temp-config
    mkdir -p $TEMP_CONFIG_DIR
    cp -r ./config/* $TEMP_CONFIG_DIR
    sed -i "s|:\ .*:8443/\${library}/|:\ ${HARBOR_REGISTRY}:8443/${DOCKER_HARBOR_LIBRARY}/|g" ${TEMP_CONFIG_DIR}/weave-net.yaml

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
	    DOCKER_IMAGE_DIRECTORY="${THIS_DIR}/docker-images"

          PROC_NUM=10
          FIFO_FILE="/tmp/$$.fifo"
          mkfifo $FIFO_FILE
          exec 9<>$FIFO_FILE

        for process_num in $(seq $PROC_NUM)
        do
          echo "$(date +%F\ %T) Processor-${process_num} Info: " >&9
        done

        for file in ${DOCKER_IMAGE_DIRECTORY}/*/*.tar
        do
            read -u 9 P
            {
                  printf "Load docker image file: $file\n"
                  echo "Process [${P}] is in process ..."

                  docker load -i $file
                  echo ${P} >&9
            }&
        done

          wait
          echo "All docker images are loaded from install disk ..."
          exec 9>&-
          rm -f ${FIFO_FILE}

    else
	    printf "Pull docker images from Docker Hub...\n"

	    ############ Will implement later ##################################

    fi
}

push_docker_images_to_harbor () {
  echo "Remove all untagged images ..."
  docker image prune
  echo "Pushing images to harbor ..."
  HARBOR_BASIC_PREFIX=${HARBOR_REGISTRY}:8443/
  HARBOR_IMAGE_PREFIX=${HARBOR_REGISTRY}:8443/${DOCKER_HARBOR_LIBRARY}/
  images=($(docker images | awk '{print $1":"$2}' | grep -v "REPOSITORY:TAG"))

  PROC_NUM=10
  FIFO_FILE="/tmp/$$.fifo"
  mkfifo $FIFO_FILE
  exec 9<>$FIFO_FILE

  for process_num in $(seq $PROC_NUM)
  do
    echo "$(date +%F\ %T) Processor-${process_num} Info: " >&9
  done

  for image in "${images[@]}"
  do
    read -u 9 P
    {
      echo "Process [${P}] is in process ..."
      new_image=${image}
      if [[ $image != ${HARBOR_IMAGE_PREFIX}* ]] && [[ $image != ${HARBOR_BASIC_PREFIX}* ]]; then
        new_image=${HARBOR_IMAGE_PREFIX}${image}
        docker tag $image $new_image
      fi
      echo "Pushing image tag $new_image to harbor"
      if [[ $new_image == ${HARBOR_IMAGE_PREFIX}* ]]; then
        docker push $new_image
      fi
      echo ${P} >&9
    }&
  done

  wait
  echo "All images are pushed to harbor ..."
  exec 9>&-
  rm -f ${FIFO_FILE}
}

prepare_k8s_images() {
  harbor_prefix=${HARBOR_REGISTRY}:8443/${DOCKER_HARBOR_LIBRARY}/
  k8s_url=k8s.gcr.io
  k8s_version=v1.18.2
  if [ "${ARCH}" == "aarch64" ]
  then
	  arch_tail="-arm64"
  else
	  arch_tail=""
  fi
  k8s_images=(
    $k8s_url/kube-proxy:$k8s_version
    $k8s_url/kube-apiserver:$k8s_version
    $k8s_url/kube-controller-manager:$k8s_version
    $k8s_url/kube-scheduler:$k8s_version
    $k8s_url/pause:3.2
    $k8s_url/etcd:3.4.3-0
    $k8s_url/coredns:1.6.7
    plndr/kube-vip:0.1.7
  )
  for image in ${k8s_images[@]}
  do
    docker pull $harbor_prefix$image${arch_tail}
    docker tag $harbor_prefix$image${arch_tail} $image
  done
}

set_up_k8s_cluster () {
    echo "The Cluster Name will be set to: ${CLUSTER_NAME}"

    swapoff -a
    sed -i '/[ \t]swap[ \t]/ s/^\(.*\)$/#\1/g' /etc/fstab
}

setup_user_on_node() {

    local node=$1

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

        ############ /etc/exports will only open to the worker_nodes client. ###############################################
        for worknode in "${worker_nodes[@]}"
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

    echo "Setting alert email ...\n
    You need to setup:
    1. smtp server host: e.g. smtp.test.com:25\n
    2. smtp server email: e.g. test_smtp@test.com\n
    3. smtp server password: e.g. TEST_PASSWORD
    4. smtp default receiver: e.g. receiver@test.com
    "

    while [ -z $alert_host ]
    do
      echo "Please set smtp server host:"
      echo "[e.g. smtp.test.com:25]>>>"
      read -r alert_host
    done
    while [ -z $alert_smtp_email_address ]
    do
      echo "Please set smtp server email address:"
      echo "[e.g. test_smtp@test.com]>>>"
      read -r alert_smtp_email_address
    done
    while [ -z $alert_smtp_email_password ]
    do
      echo "Please set smtp server email password:"
      echo "[e.g. TEST_PASSWORD]>>>"
      read -r alert_smtp_email_password
    done
    while [ -z $alert_default_user_email ]
    do
      echo "Please set default receiver email:"
      echo "[e.g. receiver@test.com]>>>"
      read -r alert_default_user_email
    done


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
private_docker_registry: ${HARBOR_REGISTRY}:8443/${DOCKER_HARBOR_LIBRARY}/
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
    server: ${master_hostname}
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
    - admin
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
    smtp_url:
    login:
    password:
    sender:
    receiver: []

grafana_alert:
  smtp:
    host: $alert_host
    user: $alert_smtp_email_address
    password: $alert_smtp_email_password
    from_address: $alert_smtp_email_address
  receiver: $alert_default_user_email

kube-vip: ${kube_vip}
endpoint_use_private_ip: true
machines:
  ${master_hostname}:
    role: infrastructure
    private-ip: ${master_ip}
    archtype: amd64
EOF

if [ ${USE_MASTER_NODE_AS_WORKER} = 0 ]; then
    cat << EOF >> config.yaml
    type: cpu
EOF
else
    cat << EOF >> config.yaml
    type: gpu
    vendor: nvidia
    os: ubuntu
EOF
fi

# write extra master nodes info
for masternode in "${extra_master_nodes[@]}"
do
   extra_master_ip=`grep "${masternode}" /etc/hosts | grep -v 127 | grep -v ${masternode}\. | awk '{print $1}'`
   cat << EOF >> config.yaml

  ${masternode}:
    role: infrastructure
    private-ip: ${extra_master_ip}
    archtype: amd64
EOF
    if [ ${USE_MASTER_NODE_AS_WORKER} = 0 ]; then
        cat << EOF >> config.yaml
    type: cpu
EOF
    else
            cat << EOF >> config.yaml
    type: gpu
    vendor: nvidia
    os: ubuntu
EOF
    fi
done
# write worker nodes info
for i in "${!worker_nodes[@]}"
do
   cat << EOF >> config.yaml

  ${worker_nodes[$i]}:
    role: worker
    archtype: ${worker_nodes_arch[$i]}
    type: ${worker_nodes_gpuType[$i]}
    vendor: ${worker_nodes_vendor[$i]}
    os: ubuntu

EOF
done

cat << EOF >> config.yaml

extranet_protocol: http

EOF

}


init_environment() {
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
  HARBOR_REGISTRY=harbor.sigsus.cn
  CLUSTER_NAME="DLWorkspace"

  ############# Don't source the install file. Run it in sh or bash ##########
  if ! echo "$0" | grep '\.sh$' > /dev/null; then
      printf 'Please run using "bash" or "sh", but not "." or "source"\\n' >&2
      return 1
  fi

  ############ Check CPU Aritecchure ########################################
  ARCH=$(uname -m)
  if [ $ARCH = "aarch64" ];then
    ARCHTYPE="arm64"
  else
    ARCHTYPE="amd64"
  fi
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
}


protocol_agree(){
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
}


init_message_print() {
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
  fi
}






deploy_node(){
  #################### Now, deploy node #########################################################################

  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!"
  echo "!   Start to work on node. "
  echo "!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

  echo ${extra_master_nodes[@]}
  printf "Total number of extra master nodes: ${#extra_master_nodes[@]} \\n"
  echo ${worker_nodes[@]}
  printf "Total number of worker nodes: ${#worker_nodes[@]} \\n"

  ########### setting up for master, also copy the package files and docker images files ###########################################
  REMOTE_INSTALL_DIR="/tmp/install_YTung.$TIMESTAMP"
  REMOTE_APT_DIR="${REMOTE_INSTALL_DIR}/apt/${ARCH}"
  REMOTE_IMAGE_DIR="${REMOTE_INSTALL_DIR}/docker-images/${ARCH}"
  REMOTE_CONFIG_DIR="${REMOTE_INSTALL_DIR}/config"
  REMOTE_PYTHON_DIR="${REMOTE_INSTALL_DIR}/python2.7"

  runuser dlwsadmin -c "ssh-keyscan ${worker_nodes[@]} >> ~/.ssh/known_hosts"

  ############# Create NFS share ###################################################################
  if [ ${NO_NFS} = 0 ]; then
     create_nfs_share
  fi


############# Config extra master node ###################################################################
echo '
           _                 __  __           _
  _____  _| |_ _ __ __ _    |  \/  | __ _ ___| |_ ___ _ __
 / _ \ \/ / __| |__/ _` |   | |\/| |/ _` / __| __/ _ \ |__|
|  __/>  <| |_| | | (_| |   | |  | | (_| \__ \ ||  __/ |
 \___/_/\_\\__|_|  \__,_|___|_|  |_|\__,_|___/\__\___|_|
                       |_____|
'
for masternode in "${extra_master_nodes[@]}"
do
	record_arch=${extra_master_nodes_arch[$i]}
	if [ "${record_arch}" == "amd64" ]
	then
		node_arch="x86_64"
	fi
	if [ "${record_arch}" == "arm64" ]
	then
		node_arch="aarch64"
	fi
	REMOTE_APT_DIR="${REMOTE_INSTALL_DIR}/apt/${node_arch}"
	REMOTE_IMAGE_DIR="${REMOTE_INSTALL_DIR}/docker-images/${node_arch}"
	REMOTE_PYTHON_DIR="${REMOTE_INSTALL_DIR}/python2.7/${node_arch}"
    ######### set up passwordless access from Master to Node ################################
    cat ~dlwsadmin/.ssh/id_rsa.pub | sshpass -p dlwsadmin ssh dlwsadmin@$masternode 'cat >> .ssh/authorized_keys'
    ######### set up passwordless access from Node to Master ################################
    sshpass -p dlwsadmin ssh dlwsadmin@$masternode cat ~dlwsadmin/.ssh/id_rsa.pub | cat >> ~dlwsadmin/.ssh/authorized_keys

    sshpass -p dlwsadmin ssh dlwsadmin@$masternode "mkdir -p ${REMOTE_INSTALL_DIR}; mkdir -p ${REMOTE_IMAGE_DIR}; mkdir -p ${REMOTE_APT_DIR}; mkdir -p ${REMOTE_CONFIG_DIR}; mkdir -p ${REMOTE_PYTHON_DIR}"

    sshpass -p dlwsadmin scp /etc/hosts dlwsadmin@$masternode:${REMOTE_INSTALL_DIR}/hosts # for docker harbor init, we need to set up hosts at begining

    sshpass -p dlwsadmin ssh dlwsadmin@$masternode "sudo cp ${REMOTE_INSTALL_DIR}/hosts /etc/hosts"

    sshpass -p dlwsadmin scp apt/${ARCH}/*.deb dlwsadmin@$masternode:${REMOTE_APT_DIR}

    sshpass -p dlwsadmin scp install_masternode_extra.sh dlwsadmin@$masternode:${REMOTE_INSTALL_DIR}

    sshpass -p dlwsadmin scp -r config/* dlwsadmin@$masternode:${REMOTE_CONFIG_DIR}

    # sshpass -p dlwsadmin scp YTung.tar.gz dlwsadmin@$masternode:${REMOTE_INSTALL_DIR}

    sshpass -p dlwsadmin scp python2.7/${node_arch}/* dlwsadmin@$masternode:${REMOTE_PYTHON_DIR}

    ########################### Install on remote node ######################################
    sshpass -p dlwsadmin ssh dlwsadmin@$masternode "cd ${REMOTE_INSTALL_DIR}; sudo bash ./install_masternode_extra.sh | tee /tmp/installation.log.$TIMESTAMP"

    #### enable nfs server ###########################################
    sshpass -p dlwsadmin ssh dlwsadmin@$masternode "sudo systemctl enable nfs-kernel-server"
	
	sshpass -p dlwsadmin ssh dlwsadmin@$masternode "docker login ${HARBOR_REGISTRY}:8443 -u admin -p ${HARBOR_ADMIN_PASSWORD}" 
    

    if [ ${NO_NFS} = 0 ]; then
       if [ $EXTERNAL_NFS_MOUNT = 0 ]; then
           EXTERNAL_MOUNT_POINT="$(hostname -I | awk '{print $1}'):${NFS_MOUNT_POINT}"
       fi
       sshpass -p dlwsadmin ssh dlwsadmin@$masternode "echo \"${EXTERNAL_MOUNT_POINT}          ${NFS_MOUNT_POINT}    nfs   auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0 \" | sudo tee -a /etc/fstab ; sudo mount ${EXTERNAL_MOUNT_POINT}  ${NFS_MOUNT_POINT}"
    fi

done
############# Config worker node ###################################################################
  echo '
                      _
  __      _____  _ __| | _____ _ __
  \ \ /\ / / _ \| |__| |/ / _ \ |__|
   \ V  V / (_) | |  |   <  __/ |
    \_/\_/ \___/|_|  |_|\_\___|_|
  '
for i in "${!worker_nodes[@]}"
do
	record_arch=${worker_nodes_arch[$i]}
	if [ "${record_arch}" == "amd64" ]
	then
		node_arch="x86_64"
	fi
	if [ "${record_arch}" == "arm64" ]
	then
		node_arch="aarch64"
	fi
	REMOTE_APT_DIR="${REMOTE_INSTALL_DIR}/apt/${node_arch}"
	REMOTE_IMAGE_DIR="${REMOTE_INSTALL_DIR}/docker-images/${node_arch}"
	REMOTE_PYTHON_DIR="${REMOTE_INSTALL_DIR}/python2.7/${node_arch}"
    ######### set up passwordless access from Master to Node ################################
    cat ~dlwsadmin/.ssh/id_rsa.pub | sshpass -p dlwsadmin ssh dlwsadmin@${worker_nodes[$i]} 'cat >> .ssh/authorized_keys'
    ######### set up passwordless access from Node to Master ################################
    sshpass -p dlwsadmin ssh dlwsadmin@${worker_nodes[$i]} cat ~dlwsadmin/.ssh/id_rsa.pub | cat >> ~dlwsadmin/.ssh/authorized_keys

    sshpass -p dlwsadmin ssh dlwsadmin@${worker_nodes[$i]} "mkdir -p ${REMOTE_INSTALL_DIR}; mkdir -p ${REMOTE_IMAGE_DIR}; mkdir -p ${REMOTE_APT_DIR}; mkdir -p ${REMOTE_CONFIG_DIR}; mkdir -p ${REMOTE_PYTHON_DIR}"

    sshpass -p dlwsadmin scp /etc/hosts dlwsadmin@${worker_nodes[$i]}:${REMOTE_INSTALL_DIR}/hosts # for docker harbor init, we need to set up hosts at begining

    sshpass -p dlwsadmin ssh dlwsadmin@${worker_nodes[$i]} "sudo cp ${REMOTE_INSTALL_DIR}/hosts /etc/hosts"

    sshpass -p dlwsadmin scp apt/${node_arch}/*.deb dlwsadmin@${worker_nodes[$i]}:${REMOTE_APT_DIR}

    sshpass -p dlwsadmin scp install_worknode.sh dlwsadmin@${worker_nodes[$i]}:${REMOTE_INSTALL_DIR}

    sshpass -p dlwsadmin scp -r config/* dlwsadmin@${worker_nodes[$i]}:${REMOTE_CONFIG_DIR}

    sshpass -p dlwsadmin scp python2.7/${node_arch}/* dlwsadmin@${worker_nodes[$i]}:${REMOTE_PYTHON_DIR}

    ########################### Install on remote node ######################################
    sshpass -p dlwsadmin ssh dlwsadmin@${worker_nodes[$i]} "cd ${REMOTE_INSTALL_DIR}; sudo bash ./install_worknode.sh | tee /tmp/installation.log.$TIMESTAMP"

    #### enable nfs server ###########################################
    sshpass -p dlwsadmin ssh dlwsadmin@${worker_nodes[$i]} "sudo systemctl enable nfs-kernel-server"

    if [ ${NO_NFS} = 0 ]; then
       if [ $EXTERNAL_NFS_MOUNT = 0 ]; then
           EXTERNAL_MOUNT_POINT="$(hostname -I | awk '{print $1}'):${NFS_MOUNT_POINT}"
       fi
       sshpass -p dlwsadmin ssh dlwsadmin@${worker_nodes[$i]} "echo \"${EXTERNAL_MOUNT_POINT}          ${NFS_MOUNT_POINT}    nfs   auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0 \" | sudo tee -a /etc/fstab ; sudo mount ${EXTERNAL_MOUNT_POINT}  ${NFS_MOUNT_POINT}"
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

./deploy.py --verbose kubeadm init ha
./deploy.py --verbose copytoall ./deploy/sshkey/admin.conf /root/.kube/config

if [ ${USE_MASTER_NODE_AS_WORKER} = 1 ]; then
    ./deploy.py --verbose kubernetes uncordon
fi

./deploy.py --verbose kubeadm join ha
./deploy.py --verbose -y kubernetes labelservice
./deploy.py --verbose -y labelworker

./deploy.py --verbose kubernetes start nvidia-device-plugin
./deploy.py --verbose kubernetes start  a910-device-plugin

./deploy.py --verbose renderservice
./deploy.py --verbose renderimage
./deploy.py --verbose webui
./deploy.py --verbose nginx webui3

./deploy.py --verbose nginx fqdn
./deploy.py --verbose nginx config

./deploy.py runscriptonroles infra worker ./scripts/install_nfs.sh
./deploy.py --verbose --force mount

echo 'Please check if all nodes have mounted storage using below cmds:'
echo "    cd ${INSTALLED_DIR}/YTung/src/ClusterBootstrap"
echo "    source ${INSTALLED_DIR}/python2.7-venv/bin/activate"
echo '    ./deploy.py execonall "df -h"'
echo '                                                                '

echo 'If the storage havnt mounted yet, please try:'
echo '    ./deploy.py --verbose --force mount'
echo '    or '
echo '    ./deploy.py execonall "python /opt/auto_share/auto_share.py"'
echo '                                                                '
read -s -n1 -p "Please press any key to continue:>> "

./deploy.py --verbose kubernetes start mysql
./deploy.py --verbose kubernetes start jobmanager2 restfulapi2 monitor nginx custommetrics repairmanager2 openresty
./deploy.py --background --sudo runscriptonall scripts/npu/npu_info_gen.py
./deploy.py --verbose kubernetes start monitor

./deploy.py --verbose kubernetes start webui3
./deploy.py kubernetes start custom-user-dashboard
./deploy.py kubernetes start image-label
./deploy.py kubernetes start aiarts-frontend
./deploy.py kubernetes start aiarts-backend
./deploy.py kubernetes start data-platform

  . ../docker-images/init-container/prebuild.sh
}

choose_start_from_which_step(){

  echo '
    1. check_docker_installation
    2. check_k8s_installation
    3. install_necessary_packages
    4. prepare_nfs_storage_path
    5. install_harbor
    6. install_dlws_admin_ubuntu
    7. install_source_dir
    8. load_docker_images
    9. push_docker_images_to_harbor
    10. prepare_k8s_images
    11. set_up_k8s_cluster
    12. deploy_node
  '
  echo "Choose a step to start from: >>"
  read -r step

}

load_config_from_file() {
	NECCESSARY_ARGUMENT=(
		NFS_STORAGE_PATH
		HARBOR_STORAGE_PATH
		DOCKER_HARBOR_LIBRARY
		HARBOR_ADMIN_PASSWORD
		alert_host
		alert_smtp_email_address
		alert_smtp_email_password
		alert_default_user_email
    kube_vip
		)
	if [ ! -f "config/install_config.json" ]; then
		echo " !!!!! Can't find config file (platform.cfg), please check there is a platform.cfg under ./config directory !!!!! "
		echo " Please relaunch later while everything is ready. "
		exit
	fi
  cat << EOF > read_config.py
  import json

  with open('config/install_config.json') as f:
      data = json.load(f)
      with open('output.cfg','w') as fout:
          for key, value in data.items():
              if key != "worker_nodes" and key != "extra_master_nodes" and "_comment" not in key:
                  fout.write(key)
                  fout.write("=")
                  fout.write(value + "\n")
          fout.write("worker_nodes=(\n")
          for worker_node_info in data["worker_nodes"]:
              fout.write(worker_node_info["host"] + "\n")
          fout.write(")\n")
          fout.write("worker_nodes_gpuType=(\n")
          for worker_node_info in data["worker_nodes"]:
              fout.write(worker_node_info["gpuType"] + "\n")
          fout.write(")\n")
          fout.write("worker_nodes_vendor=(\n")
          for worker_node_info in data["worker_nodes"]:
              fout.write(worker_node_info["vendor"] + "\n")
          fout.write(")\n")
          fout.write("extra_master_nodes=(\n")
          for extra_master_nodes_info in data["extra_master_nodes"]:
              fout.write(extra_master_nodes_info["host"] + "\n")
          fout.write(")\n")
EOF

  python3 read_config.py
  source output.cfg
  rm output.cfg
  rm testoutpu.py
	for argument in NECCESSARY_ARGUMENT
	do
		eval value="$"$argument""
		if [ ! $value ]
		then
			printf "\n!!!! Argument %s is not set in config file, Please add on and relauch !!!!\n" "$argument"
			exit
		fi
	done
	if [ "$NFS_STORAGE_PATH" == "/mnt/local" ]
	then
		printf "\n!!!!Your nfs storage path has been set to /mnt/local, which is not allowed. Please reset in your config file.!!!!\n"
		exit
	fi
	if [ "$HARBOR_STORAGE_PATH" == "/data/harbor" ]
	then
		printf "\n!!!!Your harbor storage path has been set to /data/harbor, which is not allowed. Please reset in your config file.!!!!\n"
		exit
	fi
	echo "################################"
	echo " Please check if every config is correct"
	printf "\n * nfs storage path has been set to : %s" "$NFS_STORAGE_PATH"
	printf "\n * harbor storage path has been set to : %s" "$HARBOR_STORAGE_PATH"
	printf "\n * docker library name has been set to : %s" "$DOCKER_HARBOR_LIBRARY"
	printf "\n * harbor admin password has been set to : %s" "$HARBOR_ADMIN_PASSWORD"
	printf "\n * smtp server host has been set to : %s" "$alert_host"
	printf "\n * smtp server email has been set to : %s" "$alert_smtp_email_address"
	printf "\n * smtp server password has been set to : %s" "$alert_smtp_email_password"
	printf "\n * smtp default receiver has been set to : %s" "$alert_default_user_email"
	printf "\n################################"
	printf "\nAre these config correct? [ yes / (default)no ]"
	read -r check_config_string
	while [ "$check_config_string" != "yes" ] && [ "$check_config_string" != "Yes" ] && [ "$check_config_string" != "YES" ] && [ "$check_config_string" != "" ] && \
			[ "$check_config_string" != "no" ]  && [ "$check_config_string" != "No" ]  && [ "$check_config_string" != "NO" ]
	do
		printf "Please answer 'yes' or 'no':'\\n"
		printf ">>> "
		read -r check_config_string
	done
	if [ "$check_config_string" != "yes" ] && [ "$check_config_string" != "Yes" ] && [ "$check_config_string" != "YES" ] ; then
		echo " OK. Please relaunch later while everything is ready. "
		exit
	fi


	if [[ ${#extra_master_nodes[@]} -gt 0 || ${#worker_nodes[@]} -gt 0 ]]
	then
		echo "################################"
		echo "now begin to deploy node account"
		echo "################################"
	fi
	node_number=${#extra_master_nodes[@]}
	if [ ${node_number} -gt 0 ]
	then
		echo "You have config follwing extra master nodes:"
		for i in "${!extra_master_nodes[@]}"; 
		do 
      node_number=$(( ${i} + 1 ))
			printf "%s. %s:" "$node_number" "${extra_master_nodes[$i]}"
			printf "* arch type: %s" "${extra_master_nodes_arch[$i]}"
		done
	fi
	node_number=${#worker_nodes[@]}
	if [ ${node_number} -gt 0 ]
	then
		echo "You have config follwing worker nodes:"
		for i in "${!worker_nodes[@]}"; 
		do 
      node_number=$(( ${i} + 1 ))
			printf "%s. %s:" "$node_number" "${worker_nodes[$i]}"
			printf "* arch type: %s" "${worker_nodes_arch[$i]}"
			printf "* gpu type: %s" "${worker_nodes_gpuType[$i]}"
			printf "* vendor: %s" "${worker_nodes_vendor[$i]}"
		done
	fi
	printf "\nAre these configs correct? [ yes / (default)no ]"
	read -r check_node_config
	while [ "$check_node_config" != "yes" ] && [ "$check_node_config" != "Yes" ] && [ "$check_node_config" != "YES" ] && [ "$check_node_config" != "" ] && \
			[ "$check_node_config" != "no" ]  && [ "$check_node_config" != "No" ]  && [ "$check_node_config" != "NO" ]
	do
		printf "Please answer 'yes' or 'no':'\\n"
		printf ">>> "
		read -r check_node_config
	done
	if [ "$check_node_config" != "yes" ] && [ "$check_node_config" != "Yes" ] && [ "$check_node_config" != "YES" ] ; then
		echo " OK. Please relaunch later while everything is ready. "
		exit
	fi
	node_number=1
  worker_nodes_arch=()
  extra_master_nodes_arch=()
  for i in "${!extra_master_nodes[@]}";   
  do   
    nodename=${extra_master_nodes[$i]}
		printf "Set up node %s ...\\n" "${nodename}"
		setup_user_on_node $nodename
		arch_result=`sshpass -p dlwsadmin ssh dlwsadmin@${nodename} "arch"`
		if [ "${arch_result}" == "x86_64" ]
		then
			node_arch="amd64"
		fi
		if [ "${arch_result}" == "aarch64" ]
		then
			node_arch="arm64"
		fi
    extra_master_nodes_arch[${i}]=${node_arch}
		echo OK
  done  
  for i in "${!worker_nodes[@]}";   
  do   
    nodename=${worker_nodes[$i]}
		printf "Set up node %s ...\\n" "${nodename}"
		setup_user_on_node $nodename
		arch_result=`sshpass -p dlwsadmin ssh dlwsadmin@${nodename} "arch"`
		if [ "${arch_result}" == "x86_64" ]
		then
			node_arch="amd64"
		fi
		if [ "${arch_result}" == "aarch64" ]
		then
			node_arch="arm64"
		fi
    worker_nodes_arch[${i}]=${node_arch}
		echo OK
	done

}

config_init() {
	load_config_from_file
	echo "Congratulation! config file loaded completed."
	echo "Now complete reamain setting"
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

	echo '
                    _
 _ __ ___  __ _  __| |_   _
| \__/ _ \/ _` |/ _` | | | |
| | |  __/ (_| | (_| | |_| |
|_|  \___|\__,_|\__,_|\__, |
                      |___/

	'
	read -s -n1 -p "press any key to continue installing"

}

############################################################################
#
#   MAIN CODE START FROM HERE
#
############################################################################
init_environment
protocol_agree
config_init
init_message_print
choose_start_from_which_step

if [ $step -lt 2 ];
then
  check_docker_installation
fi
if [ $step -lt 3 ];
then
  check_k8s_installation
fi
if [ $step -lt 4 ];
then
  install_necessary_packages
  copy_bin_file
fi
if [ $step -lt 5 ];
then
  prepare_nfs_storage_path
fi
if [ $step -lt 6 ];
then
  # input_harbor_library_name

  install_harbor
fi
if [ $step -lt 7 ];
then
  install_dlws_admin_ubuntu

  set_up_password_less
fi
if [ $step -lt 8 ];
then
  if [ -z $DOCKER_HARBOR_LIBRARY ];then
    input_harbor_library_name
  fi
  #### set up DLWorkspace source tree ####################################
  install_source_dir && echo "Successfully installed source tree..."

  #### check if there are nVidia Cards ###################################
  #${INSTALLED_DIR}/src/ClusterBootstrap/scripts/prepare_ubuntu.sh

  #### load/copy docker images ###########################################
usermod -a -G docker dlwsadmin     # Add dlwsadmin to docker group
fi
if [ $step -lt 9 ];
then
  load_docker_images
fi
if [ $step -lt 10 ];
then
  if [ -z $DOCKER_HARBOR_LIBRARY ];then
    input_harbor_library_name
  fi
  push_docker_images_to_harbor
fi
if [ $step -lt 11 ];
then
  if [ -z $DOCKER_HARBOR_LIBRARY ];then
    input_harbor_library_name
  fi
  prepare_k8s_images

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

fi
if [ $step -lt 12 ];
then
  #### Now, this is basic setting of K8s services ####################
  if [ -z $DOCKER_HARBOR_LIBRARY ];then
    input_harbor_library_name
  fi
  set_up_k8s_cluster
fi
if [ $step -lt 13 ];
  if [ -z $DOCKER_HARBOR_LIBRARY ];then
    input_harbor_library_name
  fi
then
  deploy_node

fi
