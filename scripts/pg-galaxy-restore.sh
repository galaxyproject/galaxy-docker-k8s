#!/bin/bash

# Restores galaxy from SQL script file inside postgres container. Galaxy user/db must exist.
# Required argument: port number. To get the port number, run `docker ps`:
# > docker ps
#CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                     NAMES
#0ba2d68af1de        postgres:10.6       "docker-entrypoint.s…"   35 minutes ago      Up 35 minutes       0.0.0.0:32772->5432/tcp   gpsql
#
#In the above output, 32772 is the port number.

USAGE="Usage: pg-galaxy-restore.sh port < sql-dump-file (see comments in file)"
PORT=${1:?"${USAGE}"}

set -e

psql -h localhost -p $1 -U postgres -d galaxy
	
