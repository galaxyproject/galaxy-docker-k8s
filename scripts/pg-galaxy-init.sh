#!/bin/bash

# Creates galaxy user+db, updates privileges/ownership in a new database inside postgres container

docker exec -i gpsql \
psql -U postgres -v ON_ERROR_STOP=1 <<EOSQL
		CREATE DATABASE galaxy;
		CREATE USER galaxydbuser;
		ALTER ROLE galaxydbuser WITH PASSWORD '42';
		GRANT ALL PRIVILEGES ON DATABASE galaxy TO galaxydbuser;
		ALTER DATABASE galaxy OWNER TO galaxydbuser;
EOSQL
