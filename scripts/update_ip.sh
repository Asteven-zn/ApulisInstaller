#### import function from install_DL
. ./install_DL.sh --source-only



DLWS_HOME="/home/dlwsadmin"
INSTALLED_DIR="/home/dlwsadmin/DLWorkspace"
DLWS_CONFIG_DIR="${INSTALLED_DIR}/YTung/src/ClusterBootstrap"
CONFIG_JSON_PATH="config/install_config.json"
############################################################################
#
#   MAIN CODE START FROM HERE
#
############################################################################


echo '
* Notice *
1. Please make sure /etc/hosts has been updated.
2. Please make sure ${CONFIG_JSON_PATH} exists, and has been updated.
* Notice *
Press any [Enter] to continue >>>
'
read -r dump
# reset config.yaml
if [ ! -f "${CONFIG_JSON_PATH}" ]
then
    printf "!!! Can't find config json file !!!\n" ${hostname}
    printf " Please make sure everything is ready and relaunch again. \n"
    exit
fi
if [ ! -f "config/install_config.json" ]; then
    echo " !!!!! Can't find config file (platform.cfg), please check there is a platform.cfg under ./config directory !!!!! "
    echo " Please relaunch later while everything is ready. "
    exit
fi
if [ ! -f "tools/install_DL_read_install_config.py" ]; then
    echo " !!!!! Can't find critical python script(install_DL_read_install_config.py)!!!!! "
    echo " Please relaunch later while everything is ready. "
    exit
fi
python3 tools/install_DL_read_install_config.py
source output.cfg
rm output.cfg
####### reset kubernetes and nfs
yes | kubeadm reset
/etc/init.d/rpcbind restart
/etc/init.d/nfs restart
node_number=${#extra_master_nodes[@]}
if [ ${node_number} -gt 0 ]
then
	echo "You have config follwing extra master nodes:"
	for i in "${!extra_master_nodes[@]}"; 
	do 
		node_number=$(( ${i} + 1 ))
		sshpass -p dlwsadmin ssh dlwsadmin@${extra_master_nodes[$i]} "yes | sudo kubeadm reset"
		sshpass -p dlwsadmin ssh dlwsadmin@${extra_master_nodes[$i]} "sudo /etc/init.d/rpcbind restart"
		sshpass -p dlwsadmin ssh dlwsadmin@${extra_master_nodes[$i]} "sudo /etc/init.d/nfs restart"
		printf "%s. %s\n" "$node_number" "${extra_master_nodes[$i]}"
	done
fi
node_number=${#worker_nodes[@]}
if [ ${node_number} -gt 0 ]
then
	echo "You have config follwing worker nodes:"
	for i in "${!worker_nodes[@]}"; 
	do 
		node_number=$(( ${i} + 1 ))
		sshpass -p dlwsadmin ssh dlwsadmin@${worker_nodes[$i]} "yes | sudo kubeadm reset"
		sshpass -p dlwsadmin ssh dlwsadmin@${worker_nodes[$i]} "sudo /etc/init.d/rpcbind restart"
		sshpass -p dlwsadmin ssh dlwsadmin@${worker_nodes[$i]} "sudo /etc/init.d/nfs restart"
		printf "%s. %s:\n" "$node_number" "${worker_nodes[$i]}"
	done
fi
############ change kube-vip
new_kube_vip=`cat config/install_config.json | grep kube_vip | sed "s?\"??g" | sed "s?.*\:??g"`
cd ${DLWS_CONFIG_DIR}
sed "s|kube-vip:.*|kube-vip: ${new_kube_vip}|g" -i config.yaml

./deploy.py --verbose copytoall /etc/hosts  /etc/hosts
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

init_cluster
deploy_services
