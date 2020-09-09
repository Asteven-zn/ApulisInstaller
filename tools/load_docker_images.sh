#!/bin/bash

COPY_DOCKER_IMAGE=1
THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
ARCH=$(uname -m)

load_docker_images () {
    if [ ${COPY_DOCKER_IMAGE} = 1 ]; then
	    printf "Copy docker images from source\n"

      echo "Please input image dir path:"
      echo ">>>"
      read -r DOCKER_IMAGE_DIRECTORY

      PROC_NUM=10
      FIFO_FILE="/tmp/$$.fifo"
      mkfifo $FIFO_FILE
      exec 9<>$FIFO_FILE
    for process_num in $(seq $PROC_NUM)
    do
      echo "$(date +%F\ %T) Processor-${process_num} Info: " >&9
    done
	for file in ${DOCKER_IMAGE_DIRECTORY}/*.tar
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

load_docker_images
