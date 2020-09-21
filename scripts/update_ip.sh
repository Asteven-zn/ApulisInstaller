DLWS_HOME="/home/dlwsadmin"
INSTALLED_DIR="/home/dlwsadmin/DLWorkspace"
DLWS_CONFIG_DIR="${INSTALLED_DIR}/YTung/src/ClusterBootstrap"
############################################################################
#
#   MAIN CODE START FROM HERE
#
############################################################################
echo '
* Notice *
1. Please make sure /etc/hosts has been updated.
2. Please make sure ./config/install_config.json exists, and has been updated.
* Notice *
Press any [Enter] to continue >>>
'
read -r dump
# reset cluster
yes | kubeadm reset
# reset config.yaml
if [ ! -f "config/install_config.json" ]
then
    printf "!!! Can't find config json file !!!\n" ${hostname}
    printf " Please make sure everything is ready and relaunch again. \n"
    exit
fi
new_kube_vip=`cat config/install_config.json | grep kube_vip | sed "s?\"??g" | sed "s?.*\:??g"`
cd ${DLWS_CONFIG_DIR}
sed "s|kube-vip:.*|kube-vip: ${new_kube_vip}|g" -i config.yaml

master_hostname=`hostname`
for hostname in `cat config.yaml | grep " role: infrastructure" -B 1 |  grep -v "infrastructure" | sed "s/\://" | grep -v "^--"`
do
    host_ip=`grep "${hostname}" /etc/hosts | grep -v 127 | grep -v ${hostname}\. | awk '{print $1}'`
    if [[ ${host_ip} == "" ]]
    then
        printf "!!! Can't find node %s in /etc/hosts !!!\n" ${hostname}
        printf " Please make sure everything is ready and relaunch again. \n"
        exit
    fi
    # grep double times, so that it can save space before "private: xxx"
    new_config=`grep "${hostname}:" config.yaml -A 2 | grep "private-ip:" | sed "s/: .*/: ${host_ip}/g"`
    origin_config=`grep "${hostname}:" config.yaml -A 2 | grep "private-ip:" `
    sed "s/${origin_config}/${new_config}/g" -i config.yaml
done

# deploy cluster again
. ./install_DL.sh --source-only
init_cluster
deploy_services
