#!/bin/bash

## oc adm policy add-scc-to-user anyuid default - wordpress-lab
## oc adm policy add-scc-to-user anyuid dev - wordpress-lab
oc apply -f os-nfs-mysql-pv.yaml 
## oc apply -f os-nfs-mysql-pvc.yaml
## oc apply -f  nfs_volumenes/os-nfs-wp-pv.yaml 
## oc apply -f  os-nfs-wp-pvc.yaml

## oc apply -f config-master.yaml
oc apply -f secrets.yaml
oc apply -f svc-master.yaml
## oc apply -f deployment-wp.yaml
oc apply -f stateful-set-master.yaml
##oc apply -f svc-wp.yaml
