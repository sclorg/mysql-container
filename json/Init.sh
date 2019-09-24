#!/bin/bash

oc apply -f os-nfs-mysql-pv01.yaml 
oc apply -f os-nfs-mysql-pv02.yaml
oc apply -f os-nfs-mysql-pv03.yaml 
oc apply -f os-nfs-mysql-pv04.yaml

oc process -f mysql_replica.json -p MYSQL_MASTER_PASSWORD=passmaster -p MYSQL_PASSWORD=pass -p MYSQL_ROOT_PASSWORD=passroot -p VOLUME_CAPACITY=4Gi  -p IMAGEN_STREAM="docker-registry.default.svc:5000/openshift/mysql-80-centos7:8.0" | oc create -f -



## $ sudo mount -t nfs -o nfsvers=4.2 ctrl.srv.world:/var/nfs-data/pv03 /home/emilio/Escritorio/wp-kubernetes_0/mysql
# $ sudo mount -t nfs -o nfsvers=4.2,rw ctrl.srv.world:/var/nfs-data/pv03 /home/emilio/Escritorio/wp-kubernetes_0/mysql
# all_squash,anonuid=0,anongid=0) da todos los privilegios a los usuarios conectados

# var/nfs-data/pv05/ *(rw,sync,wdelay,all_squash,no_subtree_check,anonuid=1000,anongid=1000)

# acceso total all_squash ,anonuid=0,anongid=0
