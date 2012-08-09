Faststart for 3.1.1
=====================


Assumptions
-----------

  * CentOS 6.3
  * KVM
  * MANAGED-NOVLAN
  * 1 front-end machine
  * 1 or more node controllers


To Run it
---------

First, install CentOS 6.3 using this ISO (configure your network interface!) http://www.gtlib.gatech.edu/pub/centos/6.3/isos/x86_64/CentOS-6.3-x86_64-minimal.iso

Then, follow the instructions below (To Build the Media) and create your FastStart media.

Then, install CentOS 6.3 (minimal install ISO) on the target systems, making sure to configure the network properly. Mount the media you created and run fastinstall.sh
(better documentation will be provided)

To Build the Media
------------------

FastStart consists of a set of files on a piece of media. Really, it can run from any directory, so copying the files to the target system is also acceptable. Generally, the files are placed onto a USB drive, but they should also fit onto a CD.

The process to build the release tgz file is in 2 steps. First, run builddeptar.sh, then builddist.sh

This first step pulls eucalyptus and centos updates into a directory and creates a repo structure. That gets tar'ed up. Take these steps to generate this tarball;

  * install centos 6.3 minimial onto a machine and ensure it can resolve external dns names.
  * copy all of these files onto a usb drive (2GB at least)
  * copy one of the euca-centos 64 bit base images from emis.eucalyptus.com to the usb drive.
  * mount that usb drive on the minimal centos 6.3 machine
  * run the builddeptar.sh script from the usb drive
  * copy /tmp/eucalyptus3.tgz to the usb drive, naming it for the release (i.e. eucalyptus3.1-rc1.tgz)

Next, you need to create the final tarball for release. To do this, simply run builddist.sh from the usb drive. It should create a file called faststart.tgz. You should rename that based on the version number, like faststart3.1-rc1.tgz.

That's it! That file is what you'd give people to create their own faststart usb drive, or CD!


What's different from the CentOS 5 version
------------------------------------------

This version has a single tarball of rpms instead of the separate ones last time. The included .repo files were used to pull packages using yum-downloadonly and all of the packages required were used to create a repo using "createrepo" and then tar-ed up.

This version installs from the tarball, but puts the proper .repo files in place to enable yum update to work

This version will also prompt for less things. For example, the DNS server IP is copied from the OS default and the ADDRSPERNET value is automatically set based on the size of the private subnet
