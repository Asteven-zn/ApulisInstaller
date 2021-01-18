#! /bin/bash

name=`basename $0`
dir=`dirname $0`

services=(a910-device-plugin aiarts-backend aiarts-frontend custommetrics custom-user-dashboard data-platform \
  image-label jobmanager2 kfserving knative mlflow monitor nginx node-cleaner nvidia-device-plugin openresty \
  postgres restfulapi2 volcanosh webui3)

# if specific service name then check
if [ -n "$2" ]; then
  if [[ " ${services[*]} " != *" $2 "* ]]; then
    echo "\"$2\" service not support, should be in (${services[*]})"
    exit 1
  fi
fi

case $1 in
start)
  if [ -z "$2" ]; then
    ansible-playbook -i ${dir}/hosts ${dir}/91.aiarts-start.yaml
    exit 0
  fi

  ansible-playbook -i ${dir}/hosts ${dir}/91.aiarts-start.yaml -e sn=$2
  ;;
stop)
  if [ -z "$2" ]; then
    ansible-playbook -i ${dir}/hosts ${dir}/92.aiarts-stop.yaml
    exit 0
  fi

  ansible-playbook -i ${dir}/hosts ${dir}/92.aiarts-stop.yaml -e sn=$2
  ;;
restart)
  if [ -z "$2" ]; then
    ansible-playbook -i ${dir}/hosts ${dir}/93.aiarts-restart.yaml
    exit 0
  fi

  ansible-playbook -i ${dir}/hosts ${dir}/93.aiarts-restart.yaml -e sn=$2
  ;;
*)
  echo "Usage: $name [start|stop|restart]"
  exit 1
  ;;
esac

exit 0

