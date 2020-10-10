. ./install_DL.sh --source-only

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
THIS_FILE=$(basename "$0")
THIS_PATH="$THIS_DIR/$THIS_FILE"

prepare_harbor(){
  cd /opt/harbor/
  docker-compose down
  for i in `docker images|grep ^goharbor |awk '{print $1":"$2}'`;do
    new_image="$(sed s/[/]/-/g <<< $i)"
    docker save $i -o $THIS_PATH/harbor/images/${new_image}.tar
  done

  ###
  cd /data/harbor/
  tar -zcvf harbor-data.tgz ./*
  mv harbor-data.tgz $THIS_PATH/harbor/
  cd /opt/harbor
  tar -zcvf harbor-install.tgz ./*
  mv harbor-install.tgz $THIS_PATH/harbor/
}

install_harbor
load_docker_images
push_docker_images_to_harbor
prepare_harbor