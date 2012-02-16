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

export LOGFILE=/var/log/cloudvalidator.log

function error_check {
  count=`grep -i 'error\|fail\|exception' $LOGFILE|wc -l`
  if [ $count -gt "0" ]
  then
    echo "An error occured in the last step, look at $LOGFILE for more details"
    exit -1;
  fi
}

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

count=`$EUCALYPTUS/usr/sbin/euca_conf --list-walruses|wc -l`
if [ $count -eq "0" ]
then
  echo "No walrus registered!"
  fail=true
fi

count=`$EUCALYPTUS/usr/sbin/euca_conf --list-clusters|wc -l`
if [ $count -eq "0" ]
then
  echo "No cluster controllers registered!"
  fail=true
fi

count=`$EUCALYPTUS/usr/sbin/euca_conf --list-scs|wc -l`
if [ $count -eq "0" ]
then
  echo "No storage controllers registered!"
  fail=true
fi

# because the cc doesn't always see the ncs right away, we'll do a retry loop
# till we do, or a time elapses (5 minutes seems safe)
retries=0;
while [ `$EUCALYPTUS/usr/sbin/euca_conf --list-nodes|wc -l` -eq "0" ]
do
  echo "No node controllers found, retrying."
  sleep 15
  retries=$(($retries + 1))
  if [ $retries -eq 20 ]
  then
    fail=true
	break
  fi
done

INSTALL_DIR=`pwd`
cd /root
echo "$(date)- Downloading admin credentials and checking configuration" |tee -a $LOGFILE
euca_conf --get-credentials credentials.zip >>$LOGFILE 2>&1
jar xf credentials.zip >>$LOGFILE 2>&1
source eucarc >>$LOGFILE 2>&1
# loop and retry on this as well. compute resources should come on-line in a minute or less
retries=0;
while [ `euca-describe-availability-zones verbose |grep m1.small | awk '{ print $4; }'` -eq "0" ]
do
  echo "No compute resource, retrying."
  sleep 15
  retries=$(($retries + 1))
  if [ $retries -eq 20 ]
  then
    fail=true
    break
  fi
done

if [ $fail ]
then
  echo "A configuration problem was detected. Please investigate and to re-run"
  echo "this check and to load a default image, run "./cloudvalidator.sh" from"
  echo "the usb drive."
  exit -1
fi

echo "$(date)- Configuration checks out!" |tee -a $LOGFILE
echo "$(date)- Loading default image" |tee -a $LOGFILE
$INSTALL_DIR/imageinstall.sh $INSTALL_DIR/euca-centos-2012.1.14-x86_64.tgz admin
echo "$(date)- Loaded default image" |tee -a $LOGFILE
