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

  #####################  Copy docker images ##########################
  mkdir -p ${INSTALLED_DOCKER_IMAGE_PATH}

  cp  ${DOCKER_IMAGE_DIR}/* ${INSTALLED_DOCKER_IMAGE_PATH}
}

getAllNeededConfigs () {

  #####################  Copy config file ##########################
  mkdir -p ${INSTALLED_CONFIG_PATH}

  cp -r ${CONFIG_DIR}/* ${INSTALLED_CONFIG_PATH}
}

install_scripts () {

  #####################  Install Scripts  ##########################
  /usr/bin/install scripts/install_DL.sh ${INSTALLED_DIR}/install_DL.sh
  /usr/bin/install scripts/install_worknode.sh ${INSTALLED_DIR}/install_worknode.sh
  #cp  ${DOCKER_IMAGE_DIR}/* ${INSTALLED_DOCKER_IMAGE_PATH}
}


install_virtual_python2 () {

    mkdir -p ${INSTALLED_DIR}/python2.7

    virtualenv --python=/usr/bin/python2.7 ${TEMP_DIR}/python2.7-venv
    (source ${TEMP_DIR}/python2.7-venv/bin/activate; cd ${INSTALLED_DIR}/python2.7; pip install setuptools; pip download aniso8601==8.0.0 certifi==2020.6.20 chardet==3.0.4 click==7.1.2 Flask==1.1.2 Flask-RESTful==0.3.8 \
     idna==2.10 itsdangerous==1.1.0 Jinja2==2.11.2 MarkupSafe==1.1.1 numpy==1.13.3 pytz==2020.1 PyYAML==5.3.1 requests==2.24.0 six==1.15.0 tzlocal==2.1 urllib3==1.25.9 Werkzeug==1.0.1 pycurl==7.43.0.5 subprocess32==3.5.4)

    #(cd ${TEMP_DIR}; tar -cvzf ${INSTALLED_DIR}/python2.tar.gz python2.7-venv )

    rm -rf ${TEMP_DIR}/python2.7-venv
}

############ Don't source the install file. Run it in sh or bash ##########
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
DOCKER_IMAGE_DIR=/home/andrew/install-test/docker-images/x86
CONFIG_DIR=./config
RM="/bin/rm"

############################ add necessary packages for python and some other python packages used by "deploy.py"
NEEDED_PACKAGES="libcurl4-openssl-dev libssl-dev nfs-kernel-server nfs-common portmap kubeadm kubectl docker.io pass gnupg2 ssh sshpass build-essential gcc g++ python3 python3-dev python3-pip apt-transport-https curl wget\\
  python-dev python-pip virtualenv nvidia-modprobe nvidia-docker2"
COMPLETED_APT_DOWNLOAD=0

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
"

if which getopt > /dev/null 2>&1; then
    OPTS=$(getopt p:d:inch "$*" 2>/dev/null)
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

INSTALLED_DOCKER_IMAGE_PATH=${INSTALLED_DIR}/docker-images/${ARCH}

INSTALLED_CONFIG_PATH=${INSTALLED_DIR}/config

NVIDIA_package_PATH=${INSTALLED_DIR}/nvidia-driver

CUDA_PACKAGE_PATH=${INSTALLED_DIR}/cuda

HARBOR_PACKAGE_PATH=${INSTALL_DIR}/harbor

getDLWorkspace

getNeededAptPackages

getHarborPackages

getAllNeededDockerImages

getAllNeededConfigs

install_scripts

install_virtual_python2

${RM} -rf ${TEMP_DIR}

echo $PWD
