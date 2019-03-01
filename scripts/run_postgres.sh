#!/bin/bash

docker run -d --rm -e POSTGRES_DB=galaxy -P --network gnet --name gpsql -v galaxydb:/var/lib/postgresql/data postgres:10.6
