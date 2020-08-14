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
getCudaPackage() {
  mkdir -p ${CUDA_PACKAGE_PATH}
  cd ${CUDA_PACKAGE_PATH}

  wget http://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda_10.2.89_440.33.01_linux.run
}

updateNvidiaPluginRequirementSource() {
  curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
  distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
  curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
  sudo apt-get update -y
}

getNvidiaDriver() {
  sudo add-apt-repository -y ppa:graphics-drivers/ppa
  sudo apt-get purge -y nvidia*
  sudo apt-get update -y

  mkdir -p ${NVIDIA_package_PATH}
  cd ${NVIDIA_package_PATH}
  apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances nvidia-driver-440 | grep "^\w" | sort -u)
}

getDLWorkspace () {

  ##################### Get DL Source Code ##############################################
  #git clone --single-branch --branch poc_distributed_job git@github.com:apulis/DLWorkspace.git ${TEMP_DIR}/YTung

  ############## Use Https instead of ssh #################################################
  git clone --single-branch --branch no_network https://github.com/apulis/DLWorkspace.git ${TEMP_DIR}/YTung

  (cd ${TEMP_DIR}; tar -cvzf ${INSTALLED_DIR}/YTung.tar.gz ./YTung --exclude "./YTung/.git" )

  rm -rf ${TEMP_DIR}/YTung
}

getNeededAptPackages () {
  #################### update nvidia docker source ##############################
  updateNvidiaPluginRequirementSource
  #####################  Create Installation Disk apt packages ##########################
  mkdir -p ${INSTALLED_DIR}/apt/${ARCH}

  if [ ${COMPLETED_APT_DOWNLOAD} = "1" ]; then
      ( cd ${INSTALLED_DIR}/apt/${ARCH}; apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances ${NEEDED_PACKAGES} | grep "^\w" | sort -u) )
  else
      ( cd ${INSTALLED_DIR}/apt/${ARCH}; apt-get download $(apt-cache depends --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances ${NEEDED_PACKAGES} | grep "^\w" | sort -u)  )
  fi
}

getHarborPackages () {
  #####################  Create Installation harbor packages ##########################
  mkdir -p ${INSTALLED_DIR}/harbor
  wget https://github.com/goharbor/harbor/releases/download/v2.0.1/harbor-offline-installer-v2.0.1.tgz -O ${INSTALLED_DIR}/harbor/harbor.tgz
  wget "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" -O ${INSTALLED_DIR}/harbor/docker-compose
}

getAllNeededDockerImages () {

  #####################  exits if no docker path are provided ##########################
  if [[ -z "$DOCKER_IMAGE_DIR" ]];
  then
      echo "no docker image path were provided, skip saving the images"
      return
  fi

  mkdir -p ${INSTALLED_DOCKER_IMAGE_PATH}

  #####################  pull library images ##########################
  for image in "${LIB_IMAGES[@]}"
  do
      new_image="$(sed s/[/]/-/g <<< $image)"

      echo "docker save $image > ${new_image}.tar"
      docker pull $image
      docker save $image > ${INSTALLED_DOCKER_IMAGE_PATH}/${new_image}.tar
      echo "image saved! path: ${INSTALLED_DOCKER_IMAGE_PATH}/${new_image}.tar"
  done


  #####################  pull app images ##########################
  for image in "${APP_IMAGES[@]}"
  do
      new_image="$(sed s/[/]/-/g <<< $image)"

      echo "docker save $image > ${new_image}.tar"
      docker save $image > ${INSTALLED_DOCKER_IMAGE_PATH}/${new_image}.tar
      echo "image saved! path: ${INSTALLED_DOCKER_IMAGE_PATH}/${new_image}.tar"
  done

}

getAllNeededConfigs () {

  #####################  Copy config file ##########################
  mkdir -p ${INSTALLED_CONFIG_PATH}

  cp -r ${CONFIG_DIR}/* ${INSTALLED_CONFIG_PATH}
}

install_scripts () {

  #####################  Install Scripts  ##########################
  /usr/bin/install scripts/install_DL.sh ${INSTALLED_DIR}/install_DL.sh
  /usr/bin/install scripts/install_masternode_extra.sh ${INSTALLED_DIR}/install_masternode_extra.sh
  /usr/bin/install scripts/install_worknode.sh ${INSTALLED_DIR}/install_worknode.sh
  #cp  ${DOCKER_IMAGE_DIR}/* ${INSTALLED_DOCKER_IMAGE_PATH}
}


install_virtual_python2 () {

    mkdir -p ${INSTALLED_DIR}/python2.7

    virtualenv --python=/usr/bin/python2.7 ${TEMP_DIR}/python2.7-venv
    (source ${TEMP_DIR}/python2.7-venv/bin/activate; cd ${INSTALLED_DIR}/python2.7; pip install setuptools; pip download aniso8601==8.0.0 certifi==2020.6.20 chardet==3.0.4 click==7.1.2 Flask==1.1.2 Flask-RESTful==0.3.8 \
     idna==2.10 itsdangerous==1.1.0 Jinja2==2.11.2 MarkupSafe==1.1.1 numpy==1.13.3 pytz==2020.1 PyYAML==5.3.1 requests==2.24.0 six==1.15.0 tzlocal==2.1 urllib3==1.25.9 Werkzeug==1.0.1 pycurl==7.43.0.5 subprocess32==3.5.4 setuptools==39.0.1)

    #(cd ${TEMP_DIR}; tar -cvzf ${INSTALLED_DIR}/python2.tar.gz python2.7-venv )

    rm -rf ${TEMP_DIR}/python2.7-venv
}

printConfigs() {

    echo "
    INSTALLED_DIR=$INSTALLED_DIR
    INSTALLED_DOCKER_IMAGE_PATH=$INSTALLED_DOCKER_IMAGE_PATH
    INSTALLED_CONFIG_PATH=$INSTALLED_CONFIG_PATH
    NVIDIA_package_PATH=$NVIDIA_package_PATH
    CUDA_PACKAGE_PATH=$CUDA_PACKAGE_PATH
    HARBOR_PACKAGE_PATH=$HARBOR_PACKAGE_PATH
    DOCKER_IMAGE_DIR=$DOCKER_IMAGE_DIR
    PROJECT_NAME=$PROJECT_NAME
    SAVE_DOCKER_IMAGES_ONLY=$SAVE_DOCKER_IMAGES_ONLY
    "
}

checkParams() {

    if [ "$SAVE_DOCKER_IMAGES_ONLY" = "1" -a "$PROJECT_NAME" = "" ]; then
        echo "error: please type project name!!"
        echo "usage: `basename $0` -p project_name_of_your_harbor -d path_to_save_image"
	exit $ERR_INVALID_PARAM
    fi
}

setImageList() {

LIB_IMAGES=(
    "harbor.sigsus.cn:8443/library/apulistech/grafana:6.7.4"
    "harbor.sigsus.cn:8443/library/apulistech/omg:0.0.1"
    "harbor.sigsus.cn:8443/library/apulistech/openresty:base"
    "harbor.sigsus.cn:8443/library/apulistech/tensorflow:1.14.0-gpu-py3"
    "harbor.sigsus.cn:8443/library/apulistech/tensorflow:2.2.0-gpu"
    "harbor.sigsus.cn:8443/library/apulistech/tensorflow:2.2.0-gpu-py3"

    "harbor.sigsus.cn:8443/library/bash:5"
    "harbor.sigsus.cn:8443/library/directxman12/k8s-prometheus-adapter:v0.7.0"
    "harbor.sigsus.cn:8443/library/dopa6/atlas200dk:atlas200dk_full_root_user"
    "harbor.sigsus.cn:8443/library/emacski/tensorflow-serving:1.15.0"
    "harbor.sigsus.cn:8443/library/emacski/tensorflow-serving:2.2.0"
    "harbor.sigsus.cn:8443/library/tensorflow/serving:2.2.0-gpu"
    "harbor.sigsus.cn:8443/library/tensorflow/serving:1.15.0-gpu"

    "harbor.sigsus.cn:8443/library/goharbor/chartmuseum-photon:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/clair-adapter-photon:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/clair-photon:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/harbor-core:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/harbor-db:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/harbor-jobservice:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/harbor-log:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/harbor-portal:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/harbor-registryctl:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/nginx-photon:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/notary-server-photon:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/notary-signer-photon:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/prepare:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/redis-photon:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/registry-photon:v2.0.1"
    "harbor.sigsus.cn:8443/library/goharbor/trivy-adapter-photon:v2.0.1"

    "harbor.sigsus.cn:8443/library/golang:1.13.7-alpine3.11"
    "harbor.sigsus.cn:8443/library/jessestuart/prometheus-operator:v0.38.0"

    "harbor.sigsus.cn:8443/library/k8s.gcr.io/coredns:1.6.7"
    "harbor.sigsus.cn:8443/library/k8s.gcr.io/etcd:3.4.3-0"
    "harbor.sigsus.cn:8443/library/k8s.gcr.io/kube-apiserver:v1.18.1"
    "harbor.sigsus.cn:8443/library/k8s.gcr.io/kube-apiserver:v1.18.2"
    "harbor.sigsus.cn:8443/library/k8s.gcr.io/kube-controller-manager:v1.18.2"
    "harbor.sigsus.cn:8443/library/k8s.gcr.io/kube-proxy:v1.18.2"
    "harbor.sigsus.cn:8443/library/k8s.gcr.io/kube-scheduler:v1.18.2"
    "harbor.sigsus.cn:8443/library/k8s.gcr.io/pause:3.2"


    "harbor.sigsus.cn:8443/library/mysql/mysql-server:8.0"
    "harbor.sigsus.cn:8443/library/node:12"
    "harbor.sigsus.cn:8443/library/node:dubnium"
    "harbor.sigsus.cn:8443/library/nvidia/cuda:latest"
    "harbor.sigsus.cn:8443/library/nvidia/k8s-device-plugin:1.11"
    "harbor.sigsus.cn:8443/library/omg:0.0.1"
    "harbor.sigsus.cn:8443/library/plndr/kube-vip:0.1.7"
    "harbor.sigsus.cn:8443/library/prom/alertmanager:v0.20.0"
    "harbor.sigsus.cn:8443/library/prom/node-exporter:v0.18.1"
    "harbor.sigsus.cn:8443/library/prom/prometheus:v2.18.0"
    "harbor.sigsus.cn:8443/library/python:3.7"
    "harbor.sigsus.cn:8443/library/python:3.8.0-alpine3.10"
    "harbor.sigsus.cn:8443/library/redis:5.0.6-alpine"
    "harbor.sigsus.cn:8443/library/ubuntu:18.04"
    "harbor.sigsus.cn:8443/library/weaveworks/weave-kube:2.6.5"
    "harbor.sigsus.cn:8443/library/weaveworks/weave-npc:2.6.5"
)

APP_IMAGES=(
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/a910-device-plugin:devel3"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/aiarts-frontend:1.0.0"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/apulis-huawei-dev_a910-device-plugin:latest"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/backendbase:1.9"

    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/cuda:10.0"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/cuda:sudo_installed"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/dlworkspace_aiarts-backend:1.0"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/dlworkspace_aiarts-frontend:1.0.0"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/dlworkspace_custom-user-dashboard-backend:latest"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/dlworkspace_custom-user-dashboard-frontend:latest"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/dlworkspace_data-platform-backend:latest"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/dlworkspace_gpu-reporter:latest"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/dlworkspace_image-label:latest"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/dlworkspace_init-container:latest"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/dlworkspace_openresty:latest"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/dlworkspace_repairmanager2:latest"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/dlworkspace_restfulapi2:latest"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/dlworkspace_webui3:latest"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/job-exporter:1.9"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/nginx:1.9"

    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/user-dashboard-backend:1.0.0"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/user-dashboard-backend:latest"

    "harbor.sigsus.cn:8443/${PROJECT_NAME}/dlworkspace_gpu-reporter:latest"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/dlworkspace_init-container:latest"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/dlworkspace_openresty:latest"

    "harbor.sigsus.cn:8443/${PROJECT_NAME}/watchdog:1.9"
    "harbor.sigsus.cn:8443/${PROJECT_NAME}/apulistech/watchdog:1.9"
)

}


############ Don't source the install file. Run it in sh or bash ##########
if ! echo "$0" | grep '\.sh$' > /dev/null; then
    printf 'Please run using "bash" or "sh", but not "." or "source"\\n' >&2
    return 1
fi

########### ERROR CODE ###################################################
ERR_INVALID_PARAM=10000


############ Check CPU Aritecchure ########################################
ARCH=$(uname -m)
printf "Hardware Architecture: ${ARCH}\n"

###########  Check Operation System ######################################
INSTALL_OS=$(grep '^ID=' /etc/os-release | awk -F'=' '{print $2}')
OS_RELEASE=$(grep '^VERSION_ID=' /etc/os-release | awk -F'=' '{print $2}')

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
THIS_FILE=$(basename "$0")
THIS_PATH="$THIS_DIR/$THIS_FILE"
DOCKER_IMAGE_DIR=
CONFIG_DIR=./config
RM="/bin/rm"

############################ add necessary packages for python and some other python packages used by "deploy.py"
NEEDED_PACKAGES="libcurl4-openssl-dev libssl-dev nfs-kernel-server nfs-common portmap kubeadm kubectl docker.io pass gnupg2 ssh sshpass build-essential gcc g++ python3 python3-dev python3-pip apt-transport-https curl wget\\
  python-dev python-pip virtualenv nvidia-modprobe nvidia-docker2"
COMPLETED_APT_DOWNLOAD=0
SAVE_DOCKER_IMAGES_ONLY=0
PROJECT_NAME=""

TEMP_DIR=.temp
INSTALLED_DIR="target"
INTERNET="1"
IS_DOWNLOAD_NVIDIA="1"
IS_DOWNLOAD_CUDA="1"

USAGE="
usage: $0 [options]

Create Installation Disk for YTung Workspace

-p     		    Install Destination Path
-n		        Installation Disk for YTung Installation with No Internet Connection. (Default)
-i              Installation Disk for YTung Installation with Internet Connection.
-c              Complete apt packages download.
-d              Path to Docker Images
-h		        print usage page.
-r		project(repo) name.
"

if which getopt > /dev/null 2>&1; then
    OPTS=$(getopt p:d:inch "$*" 2>/dev/null)
    if [ ! $? ]; then
        printf "%s\\n" "$USAGE"
        exit 2
    fi

    echo $OPTS
    eval set -- "$OPTS"

    while true; do
        case "$1" in
            -h)
                printf "%s\\n" "$USAGE"
                exit 2
                ;;
	        -p)
		        INSTALLED_DIR="$2"
		        shift;
		        shift;
		        ;;
	        -d)
		        DOCKER_IMAGE_DIR="$2"
		        shift;
		        shift;
		        ;;
	        -n)
		        INTERNET="0"
		        shift;
		        ;;
	        -i)
		        INTERNET="1"
		        shift;
		        ;;
	        -c)
		        COMPLETED_APT_DOWNLOAD="1"
		        shift;
		        ;;
	        -r)
		        PROJECT_NAME="$2"
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



INSTALL_DIR=
printf "Installed Directory: ${INSTALLED_DIR} \n"

mkdir -p ${TEMP_DIR}
mkdir -p ${INSTALLED_DIR}

INSTALLED_DIR=$(cd "${INSTALLED_DIR}"; pwd)

if [[ "$DOCKER_IMAGE_DIR" == "/*" ]]; then
    INSTALLED_DOCKER_IMAGE_PATH=${DOCKER_IMAGE_DIR}
elif [ ! -z "$DOCKER_IMAGE_DIR" ]; then
    INSTALLED_DOCKER_IMAGE_PATH=${INSTALLED_DIR}/$DOCKER_IMAGE_DIR
fi

INSTALLED_CONFIG_PATH=${INSTALLED_DIR}/config

NVIDIA_package_PATH=${INSTALLED_DIR}/nvidia-driver

CUDA_PACKAGE_PATH=${INSTALLED_DIR}/cuda

HARBOR_PACKAGE_PATH=${INSTALL_DIR}/harbor
LIB_IMAGES=()
APP_IMAGES=()

printConfigs

checkParams

setImageList

getAllNeededDockerImages

getDLWorkspace

getNeededAptPackages

getHarborPackages

getAllNeededConfigs

install_scripts

install_virtual_python2

${RM} -rf ${TEMP_DIR}

echo $PWD
