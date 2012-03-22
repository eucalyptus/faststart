Faststart for 3-devel
=====================


Assumptions
-----------

  * CentOS 6
  * KVM
  * MANAGED-NOVLAN


What's different from the CentOS 5 version
------------------------------------------

This version has a single tarball of rpms instead of the separate ones last time. The included .repo files were used to pull packages using yum-downloadonly and all of the packages required were used to create a repo using "createrepo" and then tar-ed up.

This version installs from the tarball, but puts the proper .repo files in place to enable yum update to work

To Run it
---------

Take the files in this directory, plus the image from here: http://emis.eucalyptus.com/starter-emis/euca-centos-2012.1.14-x86_64.tgz and place those on a flash drive (or CD).
Then, isntall CentOS 6.2 (minimal install ISO) on the target systems, making sure to configure the network properly. Mount the media you created and run fastinstall.sh
(better documentation will be provided)
