# OpenShift MySQL image

This repository contains Dockerfiles for MySQL images for OpenShift. Users can choose between RHEL and CentOS based images.


# Installation and Usage

Choose between CentOS7 or RHEL7 base image:

*  **RHEL7 base image**

To build a base-rhel7 image, you need to run docker build it on properly subscribed RHEL machine.

```
$ git clone https://github.com/openshift/mysql.git
$ cd mysql
$ make build TARGET=rhel7
```

*  **CentOS7 base image**

```
$ git clone https://github.com/openshift/mysql.git
$ cd mysql
$ make build
```
