#!/bin/bash

INSTALLED_DIR="/home/dlwsadmin/DLWorkspace"

source ${INSTALLED_DIR}/python2.7-venv/bin/activate
cd ${INSTALLED_DIR}/YTung/src/ClusterBootstrap

# setup configs
./deploy.py --verbose renderservice
./deploy.py --verbose renderimage
./deploy.py --verbose webui
./deploy.py --verbose nginx webui3
./deploy.py --verbose nginx fqdn
./deploy.py --verbose nginx config

# start services
./deploy.py kubernetes start mysql
./deploy.py kubernetes start jobmanager2 restfulapi2 monitor nginx custommetrics repairmanager2 openresty
./deploy.py kubernetes start webui3
./deploy.py kubernetes start custom-user-dashboard
./deploy.py kubernetes start image-label
./deploy.py kubernetes start aiarts-frontend
./deploy.py kubernetes start aiarts-backend
./deploy.py kubernetes start data-platform
