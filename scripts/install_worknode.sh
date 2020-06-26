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



install_necessary_packages () {

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
TIMESTAMP=$(date "+%Y%m%d-%H:%M:%S")

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

printf "directory: ${THIS_DIR} file: ${THIS_FILE} path: ${THIS_PATH} \n"
printf "system: ${INSTALL_OS} version: ${OS_RELEASE} \n"


printf "Install directory: $INSTALLED_DIR \n"
printf "Cluster Name:  $CLUSTER_NAME \n"


########### Assume install is interactive (Can change later) #############
BATCH=0

########### First of all, check if you have root privilleges #############
RUN_USER=$(ps -p $$ -o ruser=)

if [ "${INSTALL_OS}" = "ubuntu" ] ||  [ "${INSTALL_OS}" = "linuxmint" ] ;
then
    printf "Install DLWS On Ubuntu...\n"
    if [ "${OS_RELEASE}" != "18.04" ]; then
	    printf "WARNING: \n"
	    printf "       DLWorkspace is only certified on 18.04, 19.04, 19.10\n"
    fi


    check_docker_installation
    check_k8s_installation

    install_necessary_packages

    install_source_dir && echo "Successfully installed source tree..."

    #### load/copy docker images ###########################################
    usermod -a -G docker dlwsadmin     # Add dlwsadmin to docker group

    load_docker_images

fi