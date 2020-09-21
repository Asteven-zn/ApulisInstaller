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

set -x

############### load function from install_DL.sh
. ./install_DL.sh --source-only

usage() {
    cat <<EOF
Usage: $0 [options] [command]
EOF
}

config_docker_harbor_certs() {

  mkdir -p /etc/docker/certs.d
  cp -r ${THIS_DIR}/config/harbor/docker-certs.d/* /etc/docker/certs.d/
  systemctl restart docker
  echo "Docker login harbor ..."
  #docker login $HARBOR_REGISTRY --username admin
}

install_source_dir_in_extra_master () {

    if [ ! -f "${INSTALLED_DIR}" ]; then
	    mkdir -p ${INSTALLED_DIR}
    fi

    #tar -xvf ./YTung.tar.gz -C ${INSTALLED_DIR} && echo "Source files extracted successfully!"

    # there is no need to run python virtual env on work node
    # python virtual env is prepared for deploy.py which only run on master
    # (cd ${INSTALLED_DIR}; virtualenv --python=/usr/bin/python2.7 python2.7-venv)
    # source ${INSTALLED_DIR}/python2.7-venv/bin/activate

    (cd python2.7/${ARCH}; pip install setuptools* ;pip install wheel*; python setup.py bdist_wheel;pip install ./*; tar -xf PyYAML*.tar.gz -C ${INSTALLED_DIR})
    (cd ${INSTALLED_DIR}/PyYAML*; python setup.py install )

    chown -R dlwsadmin:dlwsadmin ${INSTALLED_DIR}
}

set_docker_config() {
    systemctl daemon-reload
    systemctl restart docker
    echo "set docker config done."
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
HARBOR_REGISTRY=harbor.sigsus.cn
DOCKER_HARBOR_LIBRARY=sz_gongdianju

CLUSTER_NAME="DLWorkspace"
TIMESTAMP=$(date "+%Y%m%d-%H:%M:%S")

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
    config_docker_harbor_certs
    install_necessary_packages

    prepare_k8s_images
    check_k8s_installation
    set_up_k8s_cluster

    install_source_dir_in_extra_master && echo "Successfully installed source tree..."

    #### load/copy docker images ###########################################
    usermod -a -G docker dlwsadmin     # Add dlwsadmin to docker group

    set_docker_config

fi

########### Then, join in kubernetes cluster and apply weave net ###############################

# JOIN_COMMAND=`cat join-command`

# sudo $JOIN_COMMAND
