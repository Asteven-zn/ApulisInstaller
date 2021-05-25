#!/bin/bash

dir=`dirname $0`

if [ "istio" == "istio" ];
then
    /opt/kube/bin/istioctl install -f ${dir}/istio.yaml --set values.global.jwtPolicy=first-party-jwt --force
fi