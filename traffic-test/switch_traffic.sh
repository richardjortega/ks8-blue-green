#!/usr/bin/env bash

## Usage
##  ./switch_traffic.sh service-green.yaml

## Prereqs:
##  kubectl (connected to K8s cluster)

SERVICE_FILE=$1
kubectl apply -f $SERVICE_FILE

echo "Done."