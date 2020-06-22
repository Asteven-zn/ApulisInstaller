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



getDLWorkspace () {

  ##################### Get DL Source Code ##############################################
  #git clone --single-branch --branch poc_distributed_job git@github.com:apulis/DLWorkspace.git ${TEMP_DIR}/YTung

  ############## Use Https instead of ssh #################################################
  git clone --single-branch --branch poc_distributed_job https://github.com/apulis/DLWorkspace.git ${TEMP_DIR}/YTung

  (cd ${TEMP_DIR}; tar -cvzf ../${INSTALLED_DIR}/YTung.tar.gz ./YTung --exclude "./YTung/.git" )

  rm -rf ${TEMP_DIR}/YTung
}

getNeededAptPackages () {
  #####################  Create Installation Disk apt packages ##########################
  mkdir -p ${INSTALLED_DIR}/apt/${ARCH}

  if [ ${COMPLETED_APT_DOWNLOAD} = "1" ]; then
      ( cd ${INSTALLED_DIR}/apt/${ARCH}; apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances ${NEEDED_PACKAGES} | grep "^\w" | sort -u) )
  else
      ( cd ${INSTALLED_DIR}/apt/${ARCH}; apt-get download $(apt-cache depends --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances ${NEEDED_PACKAGES} | grep "^\w" | sort -u)  )
  fi
}

getAllNeededDockerImages () {
    
  #####################  Create Installation Disk apt packages ##########################
  mkdir -p ${INSTALLED_DOCKER_IMAGE_PATH}

  cp  ${DOCKER_IMAGE_DIR}/* ${INSTALLED_DOCKER_IMAGE_PATH}
}

install_scripts () {

  #####################  Install Scripts  ##########################
  /usr/bin/install scripts/install_DL.sh ${INSTALLED_DIR}/install_DL.sh

  #cp  ${DOCKER_IMAGE_DIR}/* ${INSTALLED_DOCKER_IMAGE_PATH}
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
RM="/bin/rm"

NEEDED_PACKAGES="kubeadm kubectl docker.io ssh build-essential gcc g++ python3 python3-dev python3-pip apt-transport-https curl wget vim"
COMPLETED_APT_DOWNLOAD=0

TEMP_DIR=.temp
INSTALLED_DIR="target"
INTERNET="1"

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


printf "Installed Directory: ${INSTALL_DIR} \n"

mkdir -p ${TEMP_DIR}
mkdir -p ${INSTALLED_DIR}


INSTALLED_DOCKER_IMAGE_PATH=${INSTALLED_DIR}/docker-images/${ARCH}

getDLWorkspace

getNeededAptPackages

getAllNeededDockerImages

install_scripts

${RM} -rf ${TEMP_DIR}

echo $PWD
