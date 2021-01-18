#! /bin/bash

name=`basename $0`
dir=`dirname $0`

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

