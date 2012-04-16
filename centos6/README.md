Faststart for 3.1
=====================


Assumptions
-----------

  * CentOS 6
  * KVM
  * MANAGED-NOVLAN
  * 1 front-end machine
  * 1 or more node controllers


What's different from the CentOS 5 version
------------------------------------------

This version has a single tarball of rpms instead of the separate ones last time. The included .repo files were used to pull packages using yum-downloadonly and all of the packages required were used to create a repo using "createrepo" and then tar-ed up.

This version installs from the tarball, but puts the proper .repo files in place to enable yum update to work

To Run it
---------

First, install CentOS 6.2 using this ISO (configure your network interface!) http://www.gtlib.gatech.edu/pub/centos/6.2/isos/x86_64/CentOS-6.2-x86_64-minimal.iso
Then, take the files in this directory, plus the image from here: http://emis.eucalyptus.com/starter-emis/euca-centos-2012.1.14-x86_64.tgz and place those on a flash drive (or CD).
Then, isntall CentOS 6.2 (minimal install ISO) on the target systems, making sure to configure the network properly. Mount the media you created and run fastinstall.sh
(better documentation will be provided)
