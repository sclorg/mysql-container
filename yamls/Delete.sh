#!/bin/bash


## oc delete -f svc-master.yaml
## oc delete -f deployment-wp.yaml
oc delete -f stateful-set-master.yaml

oc delete -f secrets.yaml

oc delete -f os-nfs-mysql-pv.yaml 
