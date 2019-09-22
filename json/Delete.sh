#!/bin/bash



oc process -f mysql_replica.json | oc delete -f -

oc delete -f os-nfs-mysql-pv01.yaml 
oc delete -f os-nfs-mysql-pv02.yaml
oc delete -f os-nfs-mysql-pv03.yaml 
oc delete -f os-nfs-mysql-pv04.yaml
