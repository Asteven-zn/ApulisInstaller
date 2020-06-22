#!/bin/sh

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
    echo "dlwsadmin ALL = (root) NOPASSWD:ALL" | tee /etc/sudoers.d/cephuser
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

    TIMESTAMP=$(date "+%Y.%m.%d-%H.%M.%S")

    TEMP_DIR="/tmp/install_ytung_apt".${TIMESTAMP}
    mkdir -p ${TEMP_DIR}


    for entry in apt/${ARCH}/*.deb
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

}

install_source_dir () {

    if [ ! -f "${INSTALLED_DIR}" ]; then
	    mkdir -p ${INSTALLED_DIR}
    fi
    
    tar -xvf ./YTung.tar.gz -C ${INSTALLED_DIR} && echo "Source files extracted successfully!"
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
	    DOCKER_IMAGE_DIRECTORY="${INSTALLED_DIR}/docker-images/${ARCH}/"

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
    sed -e '/[ \t].swap[\t ]./ s/^#*/#/' -i /etc/fstab

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
    OPTS=$(getopt d:n:r:ulh "$*" 2>/dev/null)
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

    #### Now, this is the configuration of K8s services ####################
    set_up_k8s_cluster

    ############# stop here for testing ################################################
    if [ "x" = "x" ]; then
    	echo "Exit for Now ..."
    	exit 0;
    fi


    
    ${INSTALLED_DIR}/deploy.py --verbose --archtype arm64 docker push backendbase
    ${INSTALLED_DIR}/deploy.py --verbose --archtype arm64 docker push restfulapi2
    ${INSTALLED_DIR}/deploy.py --verbose --archtype arm64 docker push webui3


    ${INSTALLED_DIR}/deploy.py --verbose webui
    

    ${INSTALLED_DIR}/deploy.py --verbose nginx fqdn
    ${INSTALLED_DIR}/deploy.py --verbose nginx config

    #### label
    ${INSTALLED_DIR}/deploy.py --verbose kubernetes uncordon
    ${INSTALLED_DIR}/deploy.py --verbose kubernetes labelservice
    ${INSTALLED_DIR}/deploy.py --verbose labelworker


fi


