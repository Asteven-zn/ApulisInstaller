#!/bin/bash

dir=`dirname $0`

dlws_scripts_file_name=${dir}/01.dlws-scripts.yaml

/opt/kube/bin/kubectl create configmap dlws-scripts --from-file=/root/build/init-scripts --dry-run -o yaml > $dlws_scripts_file_name