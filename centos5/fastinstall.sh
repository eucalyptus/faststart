#!/bin/bash
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

export VERSION=2.0.3
export ARCH=x86_64
export CLUSTER_NAME=cluster00
export LOGFILE=/var/log/fastinstall.log

function error_check {
  count=`grep -i 'error\|fail\|exception' $LOGFILE|wc -l`
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
	else
	  done="y"
    fi
  done
}

main="y"

echo "Welcome to the Euclayptus Installer"
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
echo "$(date)- Installing ntp and other regular packages" |tee -a $LOGFILE
#create local yum repo
INSTALL_DIR=`pwd`
cd /tmp
tar zxvf $INSTALL_DIR/stdpackages.tar.gz >>$LOGFILE 2>&1
cd $INSTALL_DIR
mkdir /etc/yum.repos.d/bak >>$LOGFILE 2>&1
mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/ >>$LOGFILE 2>&1
cat <<EOF> /etc/yum.repos.d/localfiles.repo
[euca-requirements]
name=Eucalyptus Standard Package Requirments
baseurl=file:///tmp/pkgs/
enabled=1
gpgcheck=0
EOF

yum install -y ntp >>$LOGFILE 2>&1
ntpdate pool.ntp.org >>$LOGFILE 2>&1
chkconfig ntpd on >>$LOGFILE 2>&1
echo "options loop max_loop=256" >> /etc/modprobe.conf 2>$LOGFILE
rmmod loop ; modprobe loop max_loop=256 >>$LOGFILE 2>&1
yum install -y java-1.6.0-openjdk ant ant-nodeps dhcp bridge-utils perl-Convert-ASN1.noarch scsi-target-utils httpd rsync vconfig wget which sudo iptables curl swig >>$LOGFILE 2>&1
error_check
echo "$(date)- Installed ntp and other regular packages" |tee -a $LOGFILE

#if NC
if [ $main = "n" ]
then
  echo "$(date)- Installing xen" |tee -a $LOGFILE
  yum install -y xen >>$LOGFILE 2>&1
  sed --in-place 's/#(xend-http-server no)/(xend-http-server yes)/' /etc/xen/xend-config.sxp  >>$LOGFILE 2>&1
  sed --in-place 's/#(xend-address localhost)/(xend-address localhost)/' /etc/xen/xend-config.sxp >>$LOGFILE 2>&1
  /etc/init.d/xend restart >>$LOGFILE 2>&1
  error_check
  echo "$(date)- Installed xen" |tee -a $LOGFILE
fi

#set std yum repos back
rm /etc/yum.repos.d/*.repo
mv /etc/yum.repos.d/bak/*.repo /etc/yum.repos.d/

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
  echo --port=22:tcp >> $FILE
  echo --port=80:tcp >> $FILE
  echo --port=443:tcp >> $FILE
fi
sed --in-place=.bak 's/enforcing/disabled/g' /etc/sysconfig/selinux >>$LOGFILE 2>&1
setenforce 0 >>$LOGFILE 2>&1
error_check
echo "$(date)- Disabled selinux" |tee -a $LOGFILE

#tarball install
echo "$(date)- Installing euca-deps" |tee -a $LOGFILE
cd /tmp
tar zxvf $INSTALL_DIR/eucalyptus-$VERSION-*.tar.gz >>$LOGFILE 2>&1
cd eucalyptus-$VERSION-*
cd eucalyptus-$VERSION*-rpm-deps-x86_64

# 2.0.2 deps
rpm -Uvh aoetools-21-1.el4.x86_64.rpm \
         euca-axis2c-1.6.0-1.x86_64.rpm \
         euca-rampartc-1.3.0-6.el5.x86_64.rpm \
         vblade-14-1mdv2008.1.x86_64.rpm \
         vtun-3.0.2-1.el5.rf.x86_64.rpm \
         lzo2-2.02-3.el5.rf.x86_64.rpm\
       	 perl-Crypt-OpenSSL-Random-0.04-1.el5.rf.x86_64.rpm\
         perl-Crypt-OpenSSL-RSA-0.25-1.el5.rf.x86_64.rpm\
         perl-Crypt-X509-0.32-1.el5.rf.noarch.rpm\
         python25-2.5.1-bashton1.x86_64.rpm\
         python25-devel-2.5.1-bashton1.x86_64.rpm\
         python25-libs-2.5.1-bashton1.x86_64.rpm >>$LOGFILE 2>&1
cd ..
error_check
echo "$(date)- Installed euca-deps" |tee -a $LOGFILE

#if front end
if [ $main = "y" ]
then
  echo "$(date)- Installing front-end server packages" |tee -a $LOGFILE
  service tgtd start >>$LOGFILE 2>&1
  chkconfig tgtd on
  rpm -Uvh eucalyptus-$VERSION-*.x86_64.rpm \
         eucalyptus-common-java-$VERSION-*.x86_64.rpm \
         eucalyptus-cloud-$VERSION-*.x86_64.rpm \
         eucalyptus-walrus-$VERSION-*.x86_64.rpm \
         eucalyptus-sc-$VERSION-*.x86_64.rpm \
         eucalyptus-cc-$VERSION-*.x86_64.rpm \
         eucalyptus-gl-$VERSION-*.x86_64.rpm >>$LOGFILE 2>&1
  error_check
  echo "$(date)- Installing front-end server dependencies" |tee -a $LOGFILE
  cd eucalyptus-$VERSION*-rpm-deps-x86_64
  rpm -Uvh aoetools-21-1.el4.x86_64.rpm \
         euca-axis2c-1.6.0-1.x86_64.rpm \
         euca-rampartc-1.3.0-6.el5.x86_64.rpm\
         perl-Crypt-OpenSSL-Random-0.04-1.el5.rf.x86_64.rpm\
         perl-Crypt-OpenSSL-RSA-0.25-1.el5.rf.x86_64.rpm\
         perl-Crypt-X509-0.32-1.el5.rf.noarch.rpm\
         python25-2.5.1-bashton1.x86_64.rpm\
         python25-devel-2.5.1-bashton1.x86_64.rpm\
         python25-libs-2.5.1-bashton1.x86_64.rpm >>$LOGFILE 2>&1
  cd ..
  error_check
  echo "$(date)- Installed front-end server packages" |tee -a $LOGFILE
fi

#if NC
if [ $main = "n" ]
then
  echo "$(date)- Installing compute node packages" |tee -a $LOGFILE
  rpm -Uvh eucalyptus-$VERSION-*.x86_64.rpm \
         eucalyptus-gl-$VERSION-*.x86_64.rpm \
         eucalyptus-nc-$VERSION-*.x86_64.rpm >>$LOGFILE 2>&1
  error_check
  echo "$(date)- Installed compute node packages" |tee -a $LOGFILE
fi
cd $INSTALL_DIR

#if NC, configure libvirt
if [ $main = "n" ]
then
  echo "$(date)- Configuring libvirt " |tee -a $LOGFILE
  echo "y" | cp -f libvirtd.conf /etc/libvirt/ >>$LOGFILE 2>&1
# can't really test until we reboot. Might want a first boot script in place to test this
#  is_running=`su eucalyptus -c "virsh list" |grep Domain |awk '{ print $3 };'`
#  if [ $is_running ]
#  then
#    echo "libvirt configured" |tee -a $LOGFILE
#  else
#    echo "unable to find running virtual domain. check $LOGFILE"  |tee -a $LOGFILE
#	exit -1;
#  fi
  error_check
  echo "$(date)- Configured libvirt " |tee -a $LOGFILE
fi

# copy our default eucalyptus.con
# only copy if we haven't done this already. We'll take default value from there in case this
# script is run a 2nd or 3rd time.
count=`grep fastinstall /etc/eucalyptus/eucalyptus.conf|wc -l`
if [ $count -eq "0" ]
then
	echo "y" | cp -f eucalyptus.conf /etc/eucalyptus/ >>$LOGFILE 2>&1
fi
sed --in-place=.bak 's/^Defaults[ ]*requiretty/#&/g' /etc/sudoers >>$LOGFILE 2>&1

#if front end
if [ $main = "y" ]
then
  echo "We need some network information"
  EUCACONFIG=/etc/eucalyptus/eucalyptus.conf
  edit_prop VNET_PUBINTERFACE "The public ethernet interface" $EUCACONFIG
  edit_prop VNET_PRIVINTERFACE "The private ethernet interface" $EUCACONFIG
  edit_prop VNET_SUBNET "Eucalyptus-only dedicated subnet" $EUCACONFIG "[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}"
  edit_prop VNET_NETMASK "Eucalyptus subnet netmask" $EUCACONFIG "[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}"
  edit_prop VNET_DNS "The DNS server address" $EUCACONFIG "[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}"
  SUBNET_VAL=`grep VNET_NETMASK $EUCACONFIG|tail -1|cut -d '=' -f 2|tr -d "\""`
  ZERO_OCTETS=`echo $SUBNET_VAL |tr "." "\n" |grep 0 |wc -l`
  ADDRSPER_REC=16
  if [ $ZERO_OCTETS -eq "3" ]	# class A subnet
  then
    ADDRSPER_REC=64
  elif [ $ZERO_OCTETS -eq "2" ] # class B subnet
  then
    ADDRSPER_REC=32
  elif [ $ZERO_OCTETS -eq "1" ] # class C subnet
  then
    ADDRSPER_REC=16
  fi
  echo "Based on the size of your private subnet, we recommend the next value be set to $ADDRSPER_REC"
  edit_prop VNET_ADDRSPERNET "How many addresses per net?" $EUCACONFIG "[0-9]*"
  edit_prop VNET_PUBLICIPS "The range of public IPs" $EUCACONFIG "[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}-[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}"
  echo "$(date)- Starting services " |tee -a $LOGFILE
  /etc/init.d/eucalyptus-cloud start >>$LOGFILE 2>&1
  /etc/init.d/eucalyptus-cc start >>$LOGFILE 2>&1
  error_check
  echo "$(date)- Started services " |tee -a $LOGFILE
fi

#if NC
if [ $main = "n" ]
then
#  /etc/init.d/eucalyptus-nc start >>$LOGFILE 2>&1
# instead of starting this now, re-boot with modifyied grub.conf to get right xen kernel
  echo "$(date)- Enabling xen kernel" |tee -a $LOGFILE
  grubby --set-default=/boot/xen.*.el5 >>$LOGFILE 2>&1
  error_check
  /sbin/chkconfig eucalyptus-nc on >>$LOGFILE 2>&1
  euca_conf -setup >>$LOGFILE 2>&1
  error_check
  echo "$(date)- Enabled xen kernel, Going to reboot to enable xen kernel, in 5 seconds" |tee -a $LOGFILE
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
  echo "Once this machine reboots, it will be ready and running as a node controller."
  echo "rebooting now"
  /sbin/reboot >>$LOGFILE 2>&1
fi

if [ $main = "y" ]
then
  echo "$(date)- Registering components " |tee -a $LOGFILE
  curl http://localhost:8443/ >/dev/null 2>&1
  while [ $? -ne 0 ]
  do
    echo "waiting for cloud controller to start"
	sleep 5
	curl http://localhost:8443/ >/dev/null 2>&1
  done
  export EUCALYPTUS=/
  export PUBLIC_IP_ADDRESS=`ip addr show eth0 |grep inet |grep global|awk -F"[\t /]*" '{ print $3 }'`
  #prompt for ip confirm
  read -p "Public IP for this node [$PUBLIC_IP_ADDRESS]" public_ip
  if [ $public_ip ]
  then
    export PUBLIC_IP_ADDRESS=$public_ip
  fi
  echo "using $PUBLIC_IP_ADDRESS to register components" |tee -a $LOGFILE
#  for i in `$EUCALYPTUS/usr/sbin/euca_conf --list-walruses|tail -n+2`
#  do
#    SVC_IP=`echo $i |awk '{ print $2 }'`
#    $EUCALYPTUS/usr/sbin/euca_conf --deregister-walrus $SVC_IP >>$LOGFILE 2>&1
#  done
  if [ `$EUCALYPTUS/usr/sbin/euca_conf --list-walruses|tail -n+2|wc -l` -eq '0' ]
  then
    $EUCALYPTUS/usr/sbin/euca_conf --register-walrus $PUBLIC_IP_ADDRESS |tee -a $LOGFILE 
  else
    echo "Walrus already registered. Will not re-register walrus" |tee -a $LOGFILE
  fi

  # deregister scs before clusters
  for i in `$EUCALYPTUS/usr/sbin/euca_conf --list-scs|tail -n+2`
  do
    SVC_IP=`echo $i |awk '{ print $1 }'`
    $EUCALYPTUS/usr/sbin/euca_conf --deregister-sc $SVC_IP >>$LOGFILE 2>&1
  done
  for i in `$EUCALYPTUS/usr/sbin/euca_conf --list-clusters|tail -n+2`
  do
    SVC_IP=`echo $i |awk '{ print $1 }'`
    $EUCALYPTUS/usr/sbin/euca_conf --deregister-cluster $SVC_IP >>$LOGFILE 2>&1
  done

  # now register clusters before scs
  $EUCALYPTUS/usr/sbin/euca_conf --register-cluster $CLUSTER_NAME $PUBLIC_IP_ADDRESS |tee -a $LOGFILE

  $EUCALYPTUS/usr/sbin/euca_conf --register-sc $CLUSTER_NAME $PUBLIC_IP_ADDRESS |tee -a $LOGFILE
  error_check

  for i in `$EUCALYPTUS/usr/sbin/euca_conf --list-nodes|tail -n+2`
  do
    SVC_IP=`echo $i |awk '{ print $2 }'`
    $EUCALYPTUS/usr/sbin/euca_conf --deregister-nodes $SVC_IP >>$LOGFILE 2>&1
  done
  echo "Ready to register node controllers. Once they are installed, enter their IP addresses here, one by one (ENTER when done)"
  done="not"
  while [ $done != "done" ]
  do
  	read -p "Node IP :" node
	if [ ! $node ]
	then
		done="done"
	else
      $EUCALYPTUS/usr/sbin/euca_conf --register-nodes $node |tee -a $LOGFILE
	fi
  done
  error_check
  echo "$(date)- Registered components " |tee -a $LOGFILE
  echo "$(date)- Installing euca2ools " |tee -a $LOGFILE
  cd /tmp
  tar zxvf $INSTALL_DIR/euca2ools-*.tar.gz >>$LOGFILE 2>&1
  cd euca2ools*
  rpm -Uvh --force python25*.rpm euca2ools*.rpm >>$LOGFILE 2>&1
  if [ `grep python2.5 /usr/sbin/euca-describe-clusters|wc -l` -eq "0" ]
  then
    sed --in-place s/python/python2.5/ /usr/sbin/euca-* >>$LOGFILE 2>&1
  fi
  error_check
  echo "$(date)- Installed euca2ools " |tee -a $LOGFILE
  cd $INSTALL_DIR
  ./cloudvalidator.sh
  echo "Please visit https://$PUBLIC_IP_ADDRESS:8443/ to start using your cluster!"
fi


