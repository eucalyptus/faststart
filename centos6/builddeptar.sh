#!/bin/bash
#
# This script pulls together the eucalyptus release packages and latest system packages
# to be used when packaging FastStart. It should be run on a system freshly installed
# with CentOS 6. The output is the eucalyptus3.tgz file in /tmp which can then be used
# directly in faststart.
#

# first, install repo files
cp euca.repo /etc/yum.repos.d/
rpm -Uvh elrepo*.rpm
rpm -Uvh epel*.rpm

# get downloadonly feature for yum
yum install -y yum-downloadonly

# fetch the OS update packages
mkdir /tmp/pkgs
yum update -y --downloadonly --downloaddir /tmp/pkgs

# fetch euca packages
yum install -y --downloadonly --downloaddir /tmp/pkgs eucalyptus-cloud eucalyptus-walrus eucalyptus-cc eucalyptus-sc eucalyptus-nc

# fetch soft deps
yum install -y --downloadonly --downloaddir /tmp/pkgs ntp zip unzip qemu-kvm

# build dir into a repo
yum install -y createrepo
cd /tmp
createrepo pkgs

# tar up pkg repo
tar czf eucalyptus3.tgz pkgs

