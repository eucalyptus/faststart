Faststart for 3.1
=====================


Assumptions
-----------

  * CentOS 6
  * KVM
  * MANAGED-NOVLAN
  * 1 front-end machine
  * 1 or more node controllers


To Run it
---------

First, install CentOS 6.2 using this ISO (configure your network interface!) http://www.gtlib.gatech.edu/pub/centos/6.2/isos/x86_64/CentOS-6.2-x86_64-minimal.iso

Then, follow the instructions below (To Build the Media) and create your FastStart media.

Then, isntall CentOS 6.2 (minimal install ISO) on the target systems, making sure to configure the network properly. Mount the media you created and run fastinstall.sh
(better documentation will be provided)

To Build the Media
------------------

FastStart consists of a set of files on a piece of media. Really, it can run from any directory, so copying the files to the target system is also acceptable. Generally, the files are placed onto a USB drive, but they should also fit onto a CD.

You'll need the files in this subdirectory, minus README.md and builddeptar.sh. You'll also need the latest euca-centos image from emis.eucalyptus.com (choose small root, 64 bit). The final requirement is the tarball of rpms which can be built using builddeptar.sh (instructions contained inside the script). The file that results from that needs to have a version number, so rename it in this format "eucalyptus3-<version>.tgz". Place all of those together on your media and you're ready to go!


What's different from the CentOS 5 version
------------------------------------------

This version has a single tarball of rpms instead of the separate ones last time. The included .repo files were used to pull packages using yum-downloadonly and all of the packages required were used to create a repo using "createrepo" and then tar-ed up.

This version installs from the tarball, but puts the proper .repo files in place to enable yum update to work

This version will also prompt for less things. For example, the DNS server IP is copied from the OS default and the ADDRSPERNET value is automatically set based on the size of the private subnet
