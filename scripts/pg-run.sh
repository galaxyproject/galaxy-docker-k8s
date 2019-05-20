#!/bin/bash

# Start postgres container
# Required argument: path to volume

USAGE="Usage: pg-run.sh path-to-volume"
VOLUMEPATH=${1:?"${USAGE}"}

docker run -d --rm  -P --network gnet --name gpsql \
-v ${VOLUMEPATH}:/var/lib/postgresql/data postgres:10.6
