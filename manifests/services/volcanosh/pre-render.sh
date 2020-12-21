#!/bin/bash

dir=`dirname $0`

nsyaml=${dir}/ns.yaml
rbacyaml=${dir}/rbac.yaml

{{ bin_dir }}/kubectl create -f $nsyaml
{{ bin_dir }}/kubectl create -f $rbacyaml
