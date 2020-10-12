. ./install_DL.sh --source-only

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
HARBOR_STORAGE_PATH="/home/harbor"
mkdir -p HARBOR_STORAGE_PATH
HARBOR_ADMIN_PASSWORD=Apulis123
HARBOR_REGISTRY=harbor.sigsus.cn
DOCKER_HARBOR_LIBRARY=sz_gongdianju

prepare_harbor(){
  cd /opt/harbor/
  docker-compose down
  for i in `docker images|grep ^goharbor |awk '{print $1":"$2}'`;do
    new_image="$(sed s/[/]/-/g <<< $i)"
    docker save $i -o $THIS_DIR/harbor/images/${new_image}.tar
  done

  ###
  cd /data/harbor/
  tar -zcvf harbor-data.tgz ./*
  mv harbor-data.tgz $THIS_DIR/harbor/
  cd /opt/harbor
  tar -zcvf harbor-install.tgz ./*
  mv harbor-install.tgz $THIS_DIR/harbor/
}

install_harbor
load_docker_images
push_docker_images_to_harbor
prepare_harbor