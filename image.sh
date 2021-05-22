#!/bin/bash

image=(
    "calico/node"
    "calico/pod2daemon-flexvol"
    "calico/cni"
    "calico/kube-controllers"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/custom-user-dashboard-backend"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/dlworkspace_webui3"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/dlworkspace_restfulapi2"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/aiarts-frontend"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/aiarts-backend"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/dlworkspace_openresty"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/custom-user-dashboard-frontend"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/postgres"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/nginx"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/vc-webhook-manager"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/vc-scheduler"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/vc-controller-manager"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/watchdog"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/grafana-zh"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/job-exporter"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/istio-proxy"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/istio-pilot"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/grafana"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/prom/prometheus"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/directxman12/k8s-prometheus-adapter"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/jessestuart/prometheus-operator"
    "registry.aliyuncs.com/google_containers/kube-proxy"
    "registry.aliyuncs.com/google_containers/kube-scheduler"
    "registry.aliyuncs.com/google_containers/kube-controller-manager"
    "registry.aliyuncs.com/google_containers/kube-apiserver"
    "registry.aliyuncs.com/google_containers/pause"
    "registry.aliyuncs.com/google_containers/coredns"
    "registry.aliyuncs.com/google_containers/etcd"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/redis"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/prom/node-exporter"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/nvidia/k8s-device-plugin"
    "harbor.apulis.cn:8443/aiarts_v1.5.0_rc8/apulistech/busybox"
)

for im in ${image[*]}
do
	#echo $im
        docker pull $im
done
