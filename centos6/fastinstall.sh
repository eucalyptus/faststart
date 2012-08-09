#!/usr/bin/env bash
#
# Copyright (c) 2011  Eucalyptus Systems, Inc.
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, only version 3 of the License.
#  
#  
#   This file is distributed in the hope that it will be useful, but WITHOUT
#   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
#   for more details.
#  
#   You should have received a copy of the GNU General Public License along
#   with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
#   Please contact Eucalyptus Systems, Inc., 6755 Hollister Ave.
#   Goleta, CA 93117 USA or visit <http://www.eucalyptus.com/licenses/>
#   if you need additional information or have any questions.
#  

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin
export VERSION=3-devel
export ARCH=x86_64
export CLUSTER_NAME=PARTI00
export LOGFILE=/var/log/fastinstall.log

function error_check {
  count=`grep -i 'error\|fail\|exception' $LOGFILE|grep -v "FAILED"|wc -l`
  if [ $count -gt "0" ]
  then
    echo "An error occured in the last step, look at $LOGFILE for more details"
    exit -1;
  fi
}

# params: prop_name, prompt, file, optional-regex
function edit_prop {
  prop_line=`grep $1 $3|tail -1`
  prop_value=`echo $prop_line |cut -d '=' -f 2|tr -d "\""`
  new_value=$prop_value
  done="n"
  while [ $done = "n" ]
  do
    read -p "$2 [$prop_value] " value
    if [ $value ]
    then
      if [ $4 ]
      then
        if [ `echo $value |grep $4` ]
        then
          new_value=$value
        else
          echo \"$value\" doesn\'t match the pattern, please refer to the previous value for input format.
        fi
      else
        new_value=$value
      fi
      if [ $new_value = $value ]
      then
        sed -i.bak "s/$1=\"$prop_value\"/$1=\"$new_value\"/g" $3
        done="y"
      fi
    elif [ `echo $prop_value| grep "x\.x\.x\.x"|wc -l` -gt 0 ]
    then
      echo "Please enter a value."
    else
      done="y"
    fi
  done
}

# function to prompt for and validate network interface
# params: prompt, default
function get_network {
  IF_NAME="blah"
  while ! echo `ip link show |grep UP |awk '{ print $2; }'|grep -v lo|tr -d ':'` | grep -E $IF_NAME > /dev/null ;
  do
    read -p "$1 [$2]: " IF_NAME
    if [ ! $IF_NAME ]
    then
      IF_NAME=$2
    fi
    if [ `ip link show $IF_NAME 2>&1 |wc -l` -lt 2 ]
    then
      echo "interface $IF_NAME not found." 1>&2
    fi
  done
  echo $IF_NAME
}

main="y"

echo "Welcome to the Eucalyptus 3.1 Installer"
echo ""
read -p "Will this be the front-end server in your cloud? [Y|n]" main_node
if [ $main_node -a $main_node = "n" ]
then
  main="n"
  echo "A node controller will be installed"
else
  echo "A cloud controller, cluster controller, walrus and storage controller will be installed"
fi

#save old log file
if [ -f $LOGFILE ]
then
  if [ -f $LOGFILE.bak ]
  then
    rm $LOGFILE.bak
  fi
  mv $LOGFILE $LOGFILE.bak
  touch $LOGFILE
fi

#for all
echo "$(date)- Installing ntp" |tee -a $LOGFILE
#create local yum repo
INSTALL_DIR=`pwd`
TEMP_DIR=`mktemp -d`
cd $TEMP_DIR
tar zxvf $INSTALL_DIR/eucalyptus3*.tgz >>$LOGFILE 2>&1
cd $INSTALL_DIR
# install repos for euca and deps
rpm -Uvh $INSTALL_DIR/eucalyptus*.rpm
rpm -Uvh $INSTALL_DIR/euca2ools*.rpm
rpm -Uvh $INSTALL_DIR/epel*.rpm
rpm -Uvh $INSTALL_DIR/elrepo*.rpm
cat <<EOF> /etc/yum.repos.d/localfiles.repo
[euca-itself]
name=Eucalyptus Standard Packages
baseurl=file://$TEMP_DIR/pkgs/
enabled=1
gpgcheck=0
EOF

echo "$(date)- Ensuring hostname resolves" |tee -a $LOGFILE
HOST_NAME=`hostname`
if [ `ping -c 1 $HOST_NAME 2>&1 |grep -c unknown` -gt "0" ]
then
  echo "$(date)- Adding $HOSTNAME to /etc/hosts" |tee -a $LOGFILE
  sed -i "1,1s/localhost/$HOST_NAME localhost/" /etc/hosts
fi

yum install -y ntp >>$LOGFILE 2>&1
# test for connectivity before trying to sync with ntpdate
if [ `ping -c 1 pool.ntp.org 2>&1 |grep -c unknown` -gt "0" ]
then
  echo "$(date)- *** Could not reach pool.ntp.org" |tee -a $LOGFILE
  echo "$(date)- *** ntp will not be enabled. You will need to ensure the clocks on machines in your cloud are synchronized." |tee -a $LOGFILE
else
  ntpdate pool.ntp.org >>$LOGFILE 2>&1
  if [ $? -gt "0" ]
  then
    echo "$(date)- Could not reach pool.ntp.org" |tee -a $LOGFILE
  fi
  service ntpd start >>$LOGFILE 2>&1
  chkconfig ntpd on >>$LOGFILE 2>&1
  hwclock --systohc >>$LOGFILE 2>&1
fi
error_check
echo "$(date)- Installed ntp" |tee -a $LOGFILE

#for all
# disable selinux
echo "$(date)- Disabling selinux" |tee -a $LOGFILE
if [ -f /etc/sysconfig/system-config-securitylevel ]
then
  sed --in-place=.bak 's/enabled/disabled/g' /etc/sysconfig/system-config-securitylevel >>$LOGFILE 2>&1
else
  FILE=/etc/sysconfig/system-config-securitylevel
  echo # Configuration file for system-config-securitylevel > $FILE
  echo --disabled >> $FILE
  echo --port=8773:tcp >> $FILE
  echo --port=8443:tcp >> $FILE
  echo --port=8774:tcp >> $FILE
  echo --port=8775:tcp >> $FILE
  echo --port=22:tcp >> $FILE
  echo --port=80:tcp >> $FILE
  echo --port=443:tcp >> $FILE
fi
sed --in-place=.bak 's/enforcing/disabled/g' /etc/sysconfig/selinux >>$LOGFILE 2>&1
sed --in-place=.bak 's/enforcing/disabled/g' /etc/selinux/config >>$LOGFILE 2>&1
setenforce 0 >>$LOGFILE 2>&1
# disable firewall
sed --in-place=.bak 's/enabled/disabled/g' /etc/sysconfig/system-config-firewall >>$LOGFILE 2>&1
grep -v "reject-with" /etc/sysconfig/iptables >/tmp/iptables
mv /etc/sysconfig/iptables /etc/sysconfig/iptables.bak
mv /tmp/iptables /etc/sysconfig
service iptables restart >>$LOGFILE 2>&1
error_check
echo "$(date)- Disabled selinux" |tee -a $LOGFILE

#if front end
if [ $main = "y" ]
then
  echo "$(date)- Updating OS packages and installing front-end server packages" |tee -a $LOGFILE
  # let's not update the OS. Slows things down and people can do that themselves
#  yum update -y >>$LOGFILE 2>&1
  yum install -y eucalyptus-cloud eucalyptus-walrus eucalyptus-cc eucalyptus-sc euca2ools unzip >>$LOGFILE 2>&1
  error_check
  echo "$(date)- Installed front-end server packages" |tee -a $LOGFILE
fi

#if NC
if [ $main = "n" ]
then
  echo "$(date)- Updating OS packages and installing compute node packages" |tee -a $LOGFILE
  # let's not update the OS. Slows things down and people can do that themselves
#  yum update -y >>$LOGFILE 2>&1
  yum install -y eucalyptus-nc >>$LOGFILE 2>&1
  error_check
  echo "$(date)- Installed compute node packages" |tee -a $LOGFILE
fi

cd $INSTALL_DIR
# cleaning up local repo packages
rm /etc/yum.repos.d/localfiles.repo
rm -rf $TEMP_DIR

#if NC, configure libvirt
if [ $main = "n" ]
then
  echo "$(date)- Configuring libvirt " |tee -a $LOGFILE
#disable dnsmasq
  service dnsmasq stop
  chkconfig dnsmasq off
  error_check
  echo "$(date)- Configured libvirt " |tee -a $LOGFILE
fi

# copy our default eucalyptus.con
# only copy if we haven't done this already. We'll take default value
# from there in case this script is run a 2nd or 3rd time.
count=`grep fastinstall /etc/eucalyptus/eucalyptus.conf|wc -l`
if [ $count -eq "0" ]
then
  echo "y" | cp -f eucalyptus.conf /etc/eucalyptus/ >>$LOGFILE 2>&1
fi

nic=`awk '{ print $1,$2 }'</proc/net/route |grep 00000000|awk '{ print $1 }'`
if [ -n $nic ]
then
  nic="em1"
fi

# if interface isn't in list of active interfaces, set to either em1 or eth0 since those seem to be
# options centos6 gives us for embedded or external nics
if [ `ip link show |grep UP |awk '{ print $2; }'|grep -v lo|tr -d ':' |grep $nic |wc -l` -eq 0 ]
then
  if [ $nic -eq 'em1' ]
  then
    nic="eth0"
  else
    nic="em1"
  fi
fi

#if front end
if [ $main = "y" ]
then
  echo "We need some network information"
  EUCACONFIG=/etc/eucalyptus/eucalyptus.conf
  # if no interfaces values are set, choose sensible default
  # (in this case, the interface used in default route)
  prop_line=`grep VNET_PUBINTERFACE $EUCACONFIG|tail -1`
  prop_value=`echo $prop_line |cut -d '=' -f 2|tr -d "\""`
  if [ $prop_value = '?' ]
  then
    sed -i.bak "s/VNET_PUBINTERFACE=\"$prop_value\"/VNET_PUBINTERFACE=\"$nic\"/g" $EUCACONFIG
    sed -i.bak "s/VNET_PRIVINTERFACE=\"$prop_value\"/VNET_PRIVINTERFACE=\"$nic\"/g" $EUCACONFIG
  fi
  echo "We need to confirm the name of the ethernet interface(s). Often, it's em1 or eth0."
  edit_prop VNET_PUBINTERFACE "The public ethernet interface" $EUCACONFIG
  edit_prop VNET_PRIVINTERFACE "The private ethernet interface (can be the same as public)" $EUCACONFIG
  echo "Next, we need a subnet that isn't used on your network to assign instance private IPs to."
  edit_prop VNET_SUBNET "Eucalyptus-only dedicated subnet" $EUCACONFIG "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"
  edit_prop VNET_NETMASK "Eucalyptus subnet netmask" $EUCACONFIG "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"

  # these lines will put the system dns server in the conf file if non was set
  DNS_SERVER=`cat /etc/resolv.conf |grep nameserver | head -1 |awk '{ print $2; }'`
  prop_line=`grep VNET_DNS $EUCACONFIG|tail -1`
  prop_value=`echo $prop_line |cut -d '=' -f 2|tr -d "\""`
  if [ $prop_value = '?.?.?.?' ]
  then
    sed -i.bak "s/VNET_DNS=\"$prop_value\"/VNET_DNS=\"$DNS_SERVER\"/g" $EUCACONFIG
    prop_value=$DNS_SERVER
  fi

  dns_first_octet=`echo $prop_value | tr "." "\n" |head -1`
  if [[ "$prop_value" == localhost || "$dns_first_octet" == 127 ]]
  then
    edit_prop VNET_DNS "The DNS server address" $EUCACONFIG "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"
  fi

  SUBNET_VAL=`grep VNET_NETMASK $EUCACONFIG|tail -1|cut -d '=' -f 2|tr -d "\""`
  ZERO_OCTETS=`echo $SUBNET_VAL |tr "." "\n" |grep 0 |wc -l`
  ADDRSPER_REC=16
  if [ $ZERO_OCTETS -eq "3" ]	# class A subnet
  then
    ADDRSPER_REC=32 # 64 would be OK, but for POC, we'll limit this
  elif [ $ZERO_OCTETS -eq "2" ] # class B subnet
  then
    ADDRSPER_REC=32
  elif [ $ZERO_OCTETS -eq "1" ] # class C subnet
  then
    ADDRSPER_REC=16
  fi
# don't prompt, just use our sensible recommendation
#  echo "Based on the size of your private subnet, we recommend the next value be set to $ADDRSPER_REC"
#  edit_prop VNET_ADDRSPERNET "How many addresses per net?" $EUCACONFIG "[0-9]*"
  prop_line=""
  prop_value=""
  prop_line=`grep VNET_ADDRSPERNET $EUCACONFIG|tail -1`
  prop_value=`echo $prop_line |cut -d '=' -f 2|tr -d "\""`
  sed -i.bak "s/$1=\"$prop_value\"/$1=\"$ADDRSPER_REC\"/g" $EUCACONFIG

  echo "Now, we need a range of public IP addresses Eucalyptus can assign to instances on your network."
  edit_prop VNET_PUBLICIPS "The range of public IPs" $EUCACONFIG "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}-[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"
  echo "$(date)- Initializing" |tee -a $LOGFILE
  $EUCALYPTUS/usr/sbin/euca_conf --initialize
  echo "$(date)- Starting services " |tee -a $LOGFILE
  /etc/init.d/eucalyptus-cloud start >>$LOGFILE 2>&1
  error_check
  echo "$(date)- Started services " |tee -a $LOGFILE
fi

#if NC
if [ $main = "n" ]
then
  # setup br0
  echo "We need to confirm the name of the ethernet interface. Often, it's em1 or eth0."
  nic=`get_network "Ethernet interface" $nic`
  pushd /etc/sysconfig/network-scripts/
  echo -e "DEVICE=br0\nTYPE=Bridge\nBOOTPROTO=static" > ifcfg-br0
  grep 'IPADDR\|GATEWAY' ifcfg-$nic >> ifcfg-br0
  IPADDRESS=`ip addr show $nic | grep global | awk '{print $2}'`
  ipcalc -m $IPADDRESS >> ifcfg-br0
  echo "ONBOOT=yes" >> ifcfg-br0
  service network stop >>$LOGFILE 2>&1
  echo "BRIDGE=br0" >> ifcfg-$nic
  popd
  service network start >>$LOGFILE 2>&1
  mkdir /var/run/eucalyptus/instances
  chown eucalyptus:eucalyptus /var/run/eucalyptus/instances
  # this will set guest timezones to UTC, which is like EC2
  sed -i -e 's/localtime/utc/' /etc/eucalyptus/libvirt.xsl
# not since we're rebooting now.
#  /etc/init.d/eucalyptus-nc start >>$LOGFILE 2>&1
# NOTE: we need to reboot so that libvirt starts properly. Nice if we can find workaround
  error_check
  /sbin/chkconfig eucalyptus-nc on >>$LOGFILE 2>&1
  error_check
  echo "$(date)- Going to reboot to enable hypervisor access, in 5 seconds" |tee -a $LOGFILE
  echo "Once this machine reboots, it will be ready and running as a node controller."
  sleep 1
  echo "4"
  sleep 1
  echo "3"
  sleep 1
  echo "2"
  sleep 1
  echo "1"
  sleep 1
  echo ""
  echo "rebooting now"
  /sbin/reboot >>$LOGFILE 2>&1
fi

if [ $main = "y" ]
then
  echo "$(date)- Registering components " |tee -a $LOGFILE
  retries=0;
  curl http://localhost:8443/ >/dev/null 2>&1
  while [ $? -ne 0 ]
  do
    echo "waiting for cloud controller to start"
	sleep 10
    retries=$(($retries + 1))
    if [ $retries -eq 30 ]  # this waits for 5 minutes
    then
      fail=true
      break
    fi
	curl http://localhost:8443/ >/dev/null 2>&1
  done
  if [ $fail ]
  then
    echo "$(date)- Cloud controller failed to start after 5 minutes. Check in /var/log/eucalyptus/startup.log" |tee -a $LOGFILE
  fi
  export EUCALYPTUS=/
  export PUBLIC_IP_ADDRESS=`ip addr show $nic |grep inet |grep global|awk -F"[\t /]*" '{ print $3 }'`
  #prompt for ip confirm
  read -p "Public IP for this node [$PUBLIC_IP_ADDRESS]" public_ip
  if [ $public_ip ]
  then
    export PUBLIC_IP_ADDRESS=$public_ip
  fi
  echo "using $PUBLIC_IP_ADDRESS to register components" |tee -a $LOGFILE
  # put ssh keys on this host, to avoid requiring user to authenticate
  count=`ls -l /root/.ssh/id_rsa|wc -l`
  if [ $count -eq "0" ]
  then
    ssh-keygen -N "" -f /root/.ssh/id_rsa
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
    ssh-keyscan -t rsa $PUBLIC_IP_ADDRESS >> /root/.ssh/known_hosts
    #chmod 600 /root/.ssh/*
  fi
  for i in `$EUCALYPTUS/usr/sbin/euca_conf --list-walruses|tail -n+2`
  do
    SVC_IP=`echo $i |awk '{ print $2 }'`
    $EUCALYPTUS/usr/sbin/euca_conf --deregister-walrus $SVC_IP >>$LOGFILE 2>&1
  done
  $EUCALYPTUS/usr/sbin/euca_conf --register-walrus -H $PUBLIC_IP_ADDRESS -C walrus -P walrus |tee -a $LOGFILE 

  # deregister scs before clusters
  for i in `$EUCALYPTUS/usr/sbin/euca_conf --list-scs|tail -n+2`
  do
    SVC_IP=`echo $i |awk '{ print $1 }'`
    $EUCALYPTUS/usr/sbin/euca_conf --deregister-sc -H $SVC_IP >>$LOGFILE 2>&1
  done
  for i in `$EUCALYPTUS/usr/sbin/euca_conf --list-clusters|tail -n+2`
  do
    SVC_IP=`echo $i |awk '{ print $1 }'`
    $EUCALYPTUS/usr/sbin/euca_conf --deregister-cluster -H $SVC_IP >>$LOGFILE 2>&1
  done

  # now register clusters before scs
  $EUCALYPTUS/usr/sbin/euca_conf --register-cluster -P $CLUSTER_NAME -H $PUBLIC_IP_ADDRESS -C cc_01 |tee -a $LOGFILE

  $EUCALYPTUS/usr/sbin/euca_conf --register-sc -P $CLUSTER_NAME -H $PUBLIC_IP_ADDRESS -C sc_01 |tee -a $LOGFILE
  error_check

  /etc/init.d/eucalyptus-cc start >>$LOGFILE 2>&1
  # need to remove ssh creds, so sync with remote nodes will work
  rm -f /root/.ssh/*
  for i in `$EUCALYPTUS/usr/sbin/euca_conf --list-nodes|tail -n+2`
  do
    SVC_IP=`echo $i |awk '{ print $2 }'`
    $EUCALYPTUS/usr/sbin/euca_conf --deregister-nodes $SVC_IP >>$LOGFILE 2>&1
  done
  echo "Ready to register node controllers. Once they are installed, enter their IP addresses here, one by one;"
  done="not"
  while [ $done != "done" ]
  do
  	read -p "Node IP (or ENTER if done):" node
	if [ ! $node ]
	then
		done="done"
	else
      $EUCALYPTUS/usr/sbin/euca_conf --register-nodes $node |tee -a $LOGFILE
	fi
  done
  error_check
  echo "$(date)- Registered components " |tee -a $LOGFILE
  ./cloudvalidator.sh
  echo "Your cloud is ready! Please visit https://$PUBLIC_IP_ADDRESS:8443/ to start using your cloud!"
fi


