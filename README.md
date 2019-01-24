An Ansible playbook for building a Galaxy container for Kubernetes.

## Setup
1. Clone the playbook repo
```
git clone https://github.com/CloudVE/galaxy-kube-playbook.git
cd galaxy-kube-playbook
```

2. Install required/dependent Ansible roles
```
ansible-galaxy install -r requirements_roles.yml -p roles
```

## Build a container image
To build an image that uses SQLite, run the following command:
```
docker build -t galaxy .
```

 To build the container so it uses an external PostgreSQL database, follow
 below steps. There are at least a couple of ways to go about initializing the
 database: (a) create it as part of the Galaxy container build process; or (b)
 import an existing schema at Galaxy start. For now, we'll use the (a) method.

1. It is necessary to link the Galaxy build container and the Postgres one. For
this, we need to create a dedicated network so the `docker build` command can
link to a running Postgres container:
```
docker network create gnet
```

2. Start the Postgres container with the newly created network and provide a
persistent volume path (make sure `/tmp/docker/volumes/postgres` exists on your
host machine, or change it to a suitable path):
```
docker run --rm -e POSTGRES_DB=galaxy -P --network gnet --name gpsql \
-v /tmp/docker/volumes/postgres:/var/lib/postgresql/data postgres:10.6
```

3. Edit `group_vars/all` to uncomment the Galaxy link to the database:
```
  galaxy:
    database_connection: postgresql://postgres@gpsql/galaxy
```

4. Build the Galaxy image:
```
docker build --network gnet -t galaxy .
```

## Run the container
To run the SQLite container and get an interactive shell, run the following:
```
docker run -it -p 8080:8080 galaxy bash
```

To start the Postgres version, run the following two commands in separate tabs:
```
docker run --rm -e POSTGRES_DB=galaxy -P --name gpsql \
-v /tmp/docker/volumes/postgres:/var/lib/postgresql/data postgres:10.6

docker run -it --rm --link gpsql:gpsql -p 8080:8080 galaxy bash
```

To start Galaxy, run `sh run.sh` within the container; once it starts, Galaxy
will be available on the host under `localhost:8080`.
