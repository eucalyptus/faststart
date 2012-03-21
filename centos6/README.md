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


