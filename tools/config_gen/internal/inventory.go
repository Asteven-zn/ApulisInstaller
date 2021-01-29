package internal

import (
	"html/template"
	"log"
)

var (
	hostsTemplate = `
[etcd]
192.168.1.154 NODE_NAME=etcd1

[kube-master]
192.168.1.154 RENDER_SERVICE=yes

[kube-worker]
192.168.1.154 RENDER_SERVICE=yes

[cluster:children]
kube-master
kube-worker

[nfs-server]
192.168.1.154

[harbor]
192.168.1.154 NEW_INSTALL=yes SELF_SIGNED_CERT=yes

[chrony]
#192.168.1.1
`
)

func GenerateInventory() {
	t, err := template.ParseGlob(hostsTemplate)
	if err != nil {
		log.Fatal("error hosts template")
		return
	}

}