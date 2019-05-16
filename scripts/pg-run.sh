docker run -d --rm  -P --network gnet --name gpsql \
-v ~/1volumes/docker/galaxy_postgres:/var/lib/postgresql/data postgres:10.6

#docker run -d --rm  -P --network gnet --name gpsql \
#-e POSTGRES_DB=galaxy -e POSTGRES_USER=galaxydbuser -e POSTGRES_PASSWORD=42 \
#-v ~/1volumes/docker/galaxy_postgres1:/var/lib/postgresql/data postgres:10.6
