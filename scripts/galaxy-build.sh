#!/bin/bash

# Build galaxy image
# Required arguments: image name + image tag

USAGE="Usage: galaxy-build.sh image-name image-tag"
IMGNAME=${1:?"${USAGE}"}
IMGTAG=${2:?"${USAGE}"}

docker build --network gnet -t ${IMGNAME}:${IMGTAG} .
