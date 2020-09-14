############################################################################
#
#   MAIN CODE START FROM HERE
#
############################################################################
yes | kubeadm reset
./deploy.py --verbose kubeadm init ha
./deploy.py --verbose copytoall ./deploy/sshkey/admin.conf /root/.kube/config

if [ ${USE_MASTER_NODE_AS_WORKER} = 1 ]; then
    ./deploy.py --verbose kubernetes uncordon
fi

./deploy.py --verbose kubeadm join ha
./deploy.py --verbose -y kubernetes labelservice
./deploy.py --verbose -y labelworker

./deploy.py --verbose kubernetes start nvidia-device-plugin
./deploy.py --verbose kubernetes start  a910-device-plugin

./deploy.py --verbose renderservice
./deploy.py --verbose renderimage
./deploy.py --verbose webui
./deploy.py --verbose nginx webui3

./deploy.py --verbose nginx fqdn
./deploy.py --verbose nginx config

./deploy.py runscriptonroles infra worker ./scripts/install_nfs.sh
./deploy.py --verbose --force mount

echo 'Please check if all nodes have mounted storage using below cmds:'
echo "    cd ${INSTALLED_DIR}/YTung/src/ClusterBootstrap"
echo "    source ${INSTALLED_DIR}/python2.7-venv/bin/activate"
echo '    ./deploy.py execonall "df -h"'
echo '                                                                '

echo 'If the storage havnt mounted yet, please try:'
echo '    ./deploy.py --verbose --force mount'
echo '    or '
echo '    ./deploy.py execonall "python /opt/auto_share/auto_share.py"'
echo '                                                                '
read -s -n1 -p "Please press any key to continue:>> "

./deploy.py --verbose kubernetes start mysql
./deploy.py --verbose kubernetes start jobmanager2 restfulapi2 monitor nginx custommetrics repairmanager2 openresty
./deploy.py --background --sudo runscriptonall scripts/npu/npu_info_gen.py
./deploy.py --verbose kubernetes start monitor

./deploy.py --verbose kubernetes start webui3
./deploy.py kubernetes start custom-user-dashboard
./deploy.py kubernetes start image-label
./deploy.py kubernetes start aiarts-frontend
./deploy.py kubernetes start aiarts-backend
./deploy.py kubernetes start data-platform

  . ../docker-images/init-container/prebuild.sh