#!/bin/bash

oc update rc mysql-master --patch='{ "apiVersion": "v1beta1", "desiredState": { "replicas": 0 }}'
oc update rc mysql-slave --patch='{ "apiVersion": "v1beta1", "desiredState": { "replicas": 0 }}'

oc delete rc mysql-master
oc delete rc mysql-slave

oc delete service mysql-master
oc delete service mysql-slave
