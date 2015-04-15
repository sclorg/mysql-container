#!/bin/bash

osc update rc mysql-master --patch='{ "apiVersion": "v1beta1", "desiredState": { "replicas": 0 }}'
osc update rc mysql-slave --patch='{ "apiVersion": "v1beta1", "desiredState": { "replicas": 0 }}'

osc delete rc mysql-master
osc delete rc mysql-slave

osc delete service mysql-master
osc delete service mysql-slave
