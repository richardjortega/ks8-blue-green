#!/usr/bin/env bash

## Usage
##  ./setup.sh

## Description:
##  Sets up a blue and green environment and service

#  Setup blue and green deployments
kubectl apply -f deployment-blue.yaml

### In a production scenario, a wait time on MinimumReplicasAvailable condition should be checked.
# Wait until the Deployment is ready by checking the MinimumReplicasAvailable condition.
# READY=$(kubectl get deploy $DEPLOYMENTNAME -o json | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
# while [[ "$READY" != "True" ]]; do
#     READY=$(kubectl get deploy $DEPLOYMENTNAME -o json | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
#     sleep 5
# done

kubectl apply -f deployment-green.yaml

# Setup service, targeting blue to start
kubectl apply -f service-blue.yaml
