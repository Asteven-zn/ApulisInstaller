#!/bin/bash

dir=`dirname $0`

config_file=${dir}/01.custom-user-dashboard-cm.yaml

/opt/kube/bin/kubectl create configmap custom-user-dashboard-cm --from-file=${dir}/local.config --dry-run -o yaml > $config_file