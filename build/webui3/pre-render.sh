#!/bin/bash

dir=`dirname $0`

webui_conf_yaml=${dir}/01.webui-cm.yaml

/opt/kube/bin/kubectl create configmap webui-cm \
  --from-file=${dir}/configAuth.json \
  --from-file=${dir}/hosting.json \
  --from-file=${dir}/local.yaml \
  --from-file=${dir}/Master-Templates.json \
  --from-file=${dir}/userconfig.json \
  --dry-run=client -o yaml > $webui_conf_yaml