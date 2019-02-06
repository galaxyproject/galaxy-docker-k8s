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
 below steps. There are at least a few ways to go about initializing the
 database: (a) create it as part of the Galaxy container build process; (b)
 import an existing schema at Galaxy start; or (c) download an archive with
 an empty database at desired migration. Below are the notes for using the (a)
 method; for option (c), a pre-built database archive can be downloaded from
 https://galaxy-helm.s3.amazonaws.com/galaxy-db-146.tar.gz.

1. It is necessary to link the Galaxy build container and the Postgres one. For
this, we need to create a dedicated network so the `docker build` command can
link to a running Postgres container:
```
docker network create gnet
```

2. Start the Postgres container with the newly created network and provide a
persistent volume path on the host where the database files will be persisted:
```
docker run --rm -e POSTGRES_DB=galaxy -e POSTGRES_PASSWORD=galaxyDBpwd -P \
--network gnet --name gpsql \
-v /tmp/docker/volumes/postgres:/var/lib/postgresql/data postgres:10.6
```

3. Edit `group_vars/all` to uncomment the Galaxy link to the database:
```
  galaxy:
    database_connection: postgresql://galaxy:galaxyDBpwd@gpsql/galaxy
```

4. Build the Galaxy image:
```
docker build --network gnet -t galaxy .
```
You may stop the Postgres container after the Galaxy image has been built.

## Run the container
To run the SQLite container and get an interactive shell, run the following:
```
docker run -it -p 8080:8080 galaxy bash
```

To start the Postgres version, first ensure that the Postgres container is running (refer to step 2
in the previous section). 

Then start the Galaxy container:
```
docker run -it --rm --network gnet -p 8080:8080 galaxy bash
```
To start Galaxy in the 'single-container' configuration, run `sh run.sh` within
the container; once it starts, Galaxy will be available on the host under
`localhost:8080`.

Alternatively, to start web handlers and job handlers as separate containers,
we need to do the following.
Start the job handler container using the following command:
```
docker run -it --rm --network gnet -p 8080:8080 galaxy bash
```

Then, exec into the created container and create the
`/galaxy/server/config/job_conf.xml` file with the following content:

```
<job_conf>
    <plugins>
        <plugin id="local" type="runner" load="galaxy.jobs.runners.local:LocalJobRunner" workers="4"/>
    </plugins>
    <handlers default="handlers">
        <handler id="handler1" tags="handlers" />
        <handler id="handler2" tags="handlers" />
    </handlers>
    <destinations>
        <destination id="local" runner="local"/>
    </destinations>
</job_conf>
```

Start the Galaxy process as normal by running `sh run.sh`.

Next, create an additional 2 containers as job handlers with the following command:

```
docker run -it --rm --network gnet galaxy bash
```

For each container, create an equivalent `job_conf.xml` file as in the web
handler container. Finally, star the web handlers with the following command,
suitably adjusting the server name as defined in the job conf:

```
/galaxy/server/scripts/galaxy-main -c config/galaxy.yml --server-name handler1
```
