#!/bin/bash

INSTALLED_DIR="/home/dlwsadmin/DLWorkspace"

source ${INSTALLED_DIR}/python2.7-venv/bin/activate
cd ${INSTALLED_DIR}/YTung/src/ClusterBootstrap


./deploy.py kubernetes start mysql
./deploy.py kubernetes start jobmanager2 restfulapi2 monitor nginx custommetrics repairmanager2 openresty
./deploy.py kubernetes start webui3
./deploy.py kubernetes start custom-user-dashboard
./deploy.py kubernetes start image-label
./deploy.py kubernetes start aiarts-frontend
./deploy.py kubernetes start aiarts-backend
./deploy.py kubernetes start data-platform
