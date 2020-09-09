#!/bin/bash

COPY_DOCKER_IMAGE=1
THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
ARCH=$(uname -m)
HARBOR_REGISTRY=harbor.sigsus.cn

clear_harbor_project_imgs () {
  echo "Clear unused harbor project images ..."
  echo "Please input harbor project name to clear: "
  echo "[e.g. sz_gongdianju]>>>"
  read -r DOCKER_HARBOR_LIBRARY
  HARBOR_IMAGE_PREFIX=${HARBOR_REGISTRY}:8443/${DOCKER_HARBOR_LIBRARY}/
  images=($(docker images | awk '{print $1":"$2}' | grep -v "REPOSITORY:TAG"))

  for image in "${images[@]}"
  do
      if [[ $image == ${HARBOR_IMAGE_PREFIX}* ]]; then
        echo "Removing $image"
        docker rmi $image
      fi
  done

  echo "All ${DOCKER_HARBOR_LIBRARY}'s images are deleted ..."
}

clear_harbor_project_imgs
