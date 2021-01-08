#!/bin/bash

if [ "$use_service" = "istio" ];
then
    if [ "$(uname -m)" = "aarch64" ]; then
      {{ bin_dir }}/istioctl install -f deploy/services/istio/istio-arm64.yaml --set values.global.jwtPolicy=first-party-jwt --force
    else
      {{ bin_dir }}/istioctl install -f deploy/services/istio/istio.yaml --set values.global.jwtPolicy=first-party-jwt --force
    fi
fi