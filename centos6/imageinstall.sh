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

export LOGFILE=/var/log/imageinstall.log

function error_check {
  count=`grep -i 'error\|fail\|exception' $LOGFILE|wc -l`
  if [ $count -gt "0" ]
  then
    echo "An error occured in the last step, look at $LOGFILE for more details"
    exit -1;
  fi
}

if [ $# -ne 2 ]
then
  echo "Usage: `basename $0` [image.tgz] [bucketname]"
  exit 65;
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

echo "$(date)- Unpacking image bundle" |tee -a $LOGFILE
cd /tmp
tar xvzf $1 >>$LOGFILE 2>&1

imagedir=`basename $1 .tgz`
echo "$(date)- Uploading kernel" |tee -a $LOGFILE
kernelname=`basename $imagedir/vmli*`
euca-bundle-image -i $imagedir/vmlin* --kernel true -p $kernelname >>$LOGFILE 2>&1
euca-upload-bundle -b $2 -m /tmp/$kernelname.manifest.xml >>$LOGFILE 2>&1
kernelid=`euca-register $2/$kernelname.manifest.xml|awk '{ print $2 }'`
echo $kernelid >> $LOGFILE
error_check

echo "$(date)- Uploading ramdisk" |tee -a $LOGFILE
ramdiskname=`basename $imagedir/initrd*`
euca-bundle-image -i $imagedir/initrd* --ramdisk true -p $ramdiskname >>$LOGFILE 2>&1
euca-upload-bundle -b $2 -m /tmp/$ramdiskname.manifest.xml >>$LOGFILE 2>&1
ramdiskid=`euca-register $2/$ramdiskname.manifest.xml|awk '{ print $2 }'`
echo $ramdiskid >> $LOGFILE
error_check

echo "$(date)- Uploading image" |tee -a $LOGFILE
imagename=`basename $imagedir/*img .img`
euca-bundle-image -i $imagedir/*img -p $imagename --kernel $kernelid --ramdisk $ramdiskid >>$LOGFILE 2>&1
euca-upload-bundle -b $2 -m /tmp/$imagename.manifest.xml >>$LOGFILE 2>&1
euca-register $2/$imagename.manifest.xml >>$LOGFILE 2>&1
error_check

echo "$(date)- Done!" |tee -a $LOGFILE
