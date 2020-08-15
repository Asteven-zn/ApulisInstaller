#!/bin/bash

COPY_DOCKER_IMAGE=1
THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
ARCH=$(uname -m)
HARBOR_REGISTRY=harbor.sigsus.cn

push_docker_images_to_harbor () {
  echo "Remove all untagged images ..."
  docker image prune
  echo "Pushing images to harbor ..."
  echo "Please input harbor project name: "
  echo "[e.g. sz_gongdianju]>>>"
  read -r DOCKER_HARBOR_LIBRARY
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
      new_image="$(sed s/harbor.sigsus.cn:8443\\/[^\\/]*\\//harbor.sigsus.cn:8443\\/${DOCKER_HARBOR_LIBRARY}\\//g <<< $new_image)"
      if [[ $image != ${HARBOR_IMAGE_PREFIX}* ]] && [[ $new_image != ${HARBOR_IMAGE_PREFIX} ]]; then
        new_image=${HARBOR_IMAGE_PREFIX}${image}
        docker tag $image $new_image
      fi
      echo "Pushing image tag $new_image to harbor"
      docker push $new_image
      echo ${P} >&9
    }&
  done

  wait
  echo "All images are pushed to harbor ..."
  exec 9>&-
  rm -f ${FIFO_FILE}
}

push_docker_images_to_harbor
