#!/bin/bash

dir=`dirname $0`

kill_idle_rule=${dir}/alerting/kill-idle.rules
grafana_zh_file_name=${dir}/07.grafana-zh-config.yaml
grafana_file_name=${dir}/07.grafana-config.yaml

alert_tmpl_file_name=${dir}/09.alert-templates.yaml
prometheus_file_name=${dir}/04.prometheus-alerting.yaml

rm $kill_idle_rule $grafana_file_name $alert_tmpl_file_name $prometheus_file_name 2> /dev/null

# config kill rules
${dir}/config_alerting.py "${dir}/../../config.yaml" > $kill_idle_rule

# generate extra grafana-config from ./grafana-config-raw
for i in `find ${dir}/grafana-config-raw/ -type f -regex ".*json" ` ; do
    ${dir}/gen_grafana-config.py ${i} ${dir}/grafana-config
done

mv ${dir}/email-notification.json ${dir}/grafana-config/

/opt/kube/bin/kubectl --namespace=kube-system create configmap alert-templates --from-file=${dir}/alert-templates --dry-run=client -o yaml > $alert_tmpl_file_name
/opt/kube/bin/kubectl --namespace=kube-system create configmap prometheus-alert --from-file=${dir}/alerting --dry-run=client -o yaml > $prometheus_file_name

###### abandon! now frontend will handle the job
#generate grafana-zh config
#generate extra grafana-config from ./grafana-zh-config-raw
#for i in `find ${dir}/grafana-zh-config-raw/ -type f -regex ".*json" ` ; do
#  ${dir}/gen_grafana-config.py ${i} ${dir}/grafana-zh-config
#done

# create zh configmap
for i in `find ${dir}/grafana-zh-config/ -type f -regex ".*json" ` ; do
  echo --from-file=$i
done | xargs /opt/kube/bin/kubectl --namespace=kube-system create configmap grafana-zh-configuration --dry-run=client -o yaml >> $grafana_zh_file_name
# create en configmap
for i in `find ${dir}/grafana-config/ -type f -regex ".*json" ` ; do
    echo --from-file=$i
done | xargs /opt/kube/bin/kubectl --namespace=kube-system create configmap grafana-configuration --dry-run=client -o yaml >> $grafana_file_name

