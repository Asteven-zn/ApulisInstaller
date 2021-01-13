#!/bin/bash

dir=`dirname $0`

if [ "{{service["use_service"]}}" == "istio" ];
then
    {{ bin_dir }}/istioctl install -f ${dir}/istio.yaml --set values.global.jwtPolicy=first-party-jwt --force
fi