#!/bin/bash

# Required argument: port number. To get the port number, run `docker ps`:
# > docker ps
#CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                     NAMES
#0ba2d68af1de        postgres:10.6       "docker-entrypoint.s…"   35 minutes ago      Up 35 minutes       0.0.0.0:32772->5432/tcp   gpsql
#
#In the above output, 32772 is the port number.
 

USAGE="Usage: pg-galaxy-init port (see comments in file)"
PORT=${1:?"${USAGE}"}

set -e

psql -h localhost -p $1 -U postgres -v ON_ERROR_STOP=1 <<-EOSQL
		CREATE DATABASE galaxy;
		CREATE USER galaxydbuser;
		ALTER ROLE galaxydbuser WITH PASSWORD '42';
		GRANT ALL PRIVILEGES ON DATABASE galaxy TO galaxydbuser;
		ALTER DATABASE galaxy OWNER TO galaxydbuser;
EOSQL
