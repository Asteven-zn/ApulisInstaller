#!/bin/bash

dir=`dirname $0`

config_file=${dir}/01.restful-cm.yaml

{{ bin_dir }}/kubectl create configmap restful-cm --from-file=${dir}/config.yaml --dry-run -o yaml > $config_file