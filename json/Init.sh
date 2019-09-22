#!/bin/bash

oc apply -f os-nfs-mysql-pv01.yaml 
oc apply -f os-nfs-mysql-pv02.yaml
oc apply -f os-nfs-mysql-pv03.yaml 
oc apply -f os-nfs-mysql-pv04.yaml

oc process -f mysql_replica.json -p MYSQL_MASTER_PASSWORD=passmaster -p MYSQL_PASSWORD=pass -p MYSQL_ROOT_PASSWORD=passroot -p VOLUME_CAPACITY=4Gi  -p IMAGEN_STREAM="docker-registry.default.svc:5000/openshift/mysql-80-centos7:8.0" | oc create -f -


