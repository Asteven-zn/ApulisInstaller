#!/bin/bash

dir=`dirname $0`

dlws_scripts_file_name=${dir}/01.dlws-scripts.yaml

{{ bin_dir }}/kubectl create configmap dlws-scripts --from-file={{ manifest_dest }}/init-scripts --dry-run -o yaml > $dlws_scripts_file_name