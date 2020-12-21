#! /bin/bash
set -x


# find ib ip, if there is no ib interface, select an available interface
HOST_CONFIG_FILE=/job/.hosts
IB_CONFIG_FILE=/job/ib_config
if [ "$DLWS_ROLE_NAME" = "worker" ] && command -v ifconfig ;
then
  interface_ip=
  # search an interface ip
  if ifconfig |grep ib -A 1|grep inet ; # if there is ib interface, which is extremely fast, select it
  then
    interface_ip=`ifconfig |grep ib -A 1|grep inet |awk '{print $2}'`
  else # if there is no ib interface, search a available interface
    virtual_interface_array=()
    available_interface=
    for virtual_interface in `ls /sys/devices/virtual/net/`
    do
	  # can't use ${ #array_name } to acquire arraya length due to jinjia transfer syntax	
	  num=`echo virtual_interface_array | wc -w`
      virtual_interface_array[${num}]=$virtual_interface
    done
    for network_interface in  `ip addr | grep -v lo| sed -r -n ' s/^[0-9]+: (.*):.*/\1/p'`
    do
      if [[ ! `ifconfig $network_interface | grep "inet " ` ]] ;
	  then
        continue
      fi
      if [[ "${virtual_interface_array[@]}" =~ "$network_interface" ]] ; then
              continue
      else
        available_interface=$network_interface
        break 
      fi
    done
    interface_ip=`ifconfig |grep $available_interface -A 1|grep inet |awk '{print $2}'`
  fi
  # check if interface ip is present
  if [ -n "$interface_ip" ]; then
    if [ ! -f $IB_CONFIG_FILE ];then touch $IB_CONFIG_FILE;fi
    if [ ! -f $HOST_CONFIG_FILE ];then touch $HOST_CONFIG_FILE;fi
    if ! cat $IB_CONFIG_FILE |grep ib-${DLWS_ROLE_NAME}-${DLWS_ROLE_IDX};
    then
      echo "ib-${DLWS_ROLE_NAME}-${DLWS_ROLE_IDX} slots=${DLWS_NUM_GPU_PER_WORKER}" >> $IB_CONFIG_FILE
    else
      sed "s/#ib-${DLWS_ROLE_NAME}-${DLWS_ROLE_IDX}.*/'ib-${DLWS_ROLE_NAME}-${DLWS_ROLE_IDX} slots=${DLWS_NUM_GPU_PER_WORKER}'/g" -i $IB_CONFIG_FILE
    fi
    if ! cat $HOST_CONFIG_FILE |grep ib-${DLWS_ROLE_NAME}-${DLWS_ROLE_IDX} ;
    then
      echo -e "${interface_ip}\tib-${DLWS_ROLE_NAME}-${DLWS_ROLE_IDX}" >> $HOST_CONFIG_FILE
    else
      sed "s/.*ib-${DLWS_ROLE_NAME}-${DLWS_ROLE_IDX}/${interface_ip}\tib-${DLWS_ROLE_NAME}-${DLWS_ROLE_IDX}/" -i $HOST_CONFIG_FILE
    fi
  fi
fi

