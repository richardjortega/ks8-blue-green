#!/usr/bin/env bash

# Usage:
#  traffic_tester.sh <APP_IP_ADDR>

HOST=$1

# Start local testing server (daemonized)
docker run -ti --net=host mercadolibre/pla http://$HOST:8080/time/9 -l 10m -c 200 -q 1666