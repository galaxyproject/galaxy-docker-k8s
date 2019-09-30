# Convenience scripts for building the image

*These instructions are just moved from the main repo README file and have
not been adopted or tested lately, so they probably won't work out of the box.*

To use these scripts, you will need to have `psql` command installed locally.
Then, run `pg-run.sh` to start the Postgres container with the newly created
network :
```
./pg-run.sh <path-to-directory>
```

If you would like to create the Galaxy database as a dedicated step (as
opposed to as part of the overall build process), run `pg-galaxy-init.sh` to create
the galaxy database user and database, and change ownership and assign
appropriate privileges, providing the port number of the Postgres container.
```
./pg-galaxy-init.sh <port-number>
```
To get the container port number, run `docker ps`:
```
> docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                 PORTS                     NAMES
0ba2d68af1de        postgres:10.6       "docker-entrypoint.s…"   35 minutes ago      Up 35    minutes       0.0.0.0:32772->5432/tcp   gpsql
#In the above output, 32772 is the port number (scroll to the right).
```

If you have a local copy of the database in a SQL dump format, instead of
building a new database, you can restore the database from a SQL script file.
To do that, run `pg-restore.sh`, providing the container port number as
argument and the SQL script file as input:
```
./pg-restore.sh <port-number> < <sql-dump-file>
```
