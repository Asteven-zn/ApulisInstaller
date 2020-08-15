#!/bin/bash

INSTALLED_DIR="/home/dlwsadmin/DLWorkspace"

source ${INSTALLED_DIR}/python2.7-venv/bin/activate
cd ${INSTALLED_DIR}/YTung/src/ClusterBootstrap


./deploy.py kubernetes stop data-platform
./deploy.py kubernetes stop aiarts-backend
./deploy.py kubernetes stop aiarts-frontend
./deploy.py kubernetes stop image-label
./deploy.py kubernetes stop custom-user-dashboard
./deploy.py kubernetes stop webui3
./deploy.py kubernetes stop jobmanager2 restfulapi2 monitor nginx custommetrics repairmanager2 openresty
./deploy.py kubernetes stop mysql
