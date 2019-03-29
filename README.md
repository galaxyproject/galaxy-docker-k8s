An Ansible playbook for building a Galaxy container for Kubernetes.

## Setup the environment for building the image
1. Clone the playbook repo
```
git clone https://github.com/CloudVE/galaxy-kube-playbook.git
cd galaxy-kube-playbook
```

2. Make sure you have Ansible installed and then install required dependent 
Ansible roles
```
ansible-galaxy install -r requirements_roles.yml -p roles
```


## Build a container image

### Build a self-contained image with SQLite database
This format of the image is useful for testing for example; the Postgres image
below is the prefered method. To start, comment out the following lines in 
`playbook.yml`:
```
  galaxy:
    database_connection: postgresql://galaxydbuser:42@gpsql/galaxy
```

Then run the following command:
```
docker build -t galaxy .
```

### Build an image configured for the PostgreSQL database
To build the container so it uses an external PostgreSQL database, follow
below steps. There are at least a few ways to go about initializing the
database: (a) create it as part of the Galaxy container build process; (b)
import an existing schema at Galaxy start; or (c) download an archive with
an empty database at desired migration. We'll cover options (a) and (c); for
option (c) download a pre-built database archive from
https://s3.amazonaws.com/galaxy-helm-dev/galaxy-db.tar.gz and extract it to
`/tmp/docker/volumes/galaxy_postgres`

1. It is necessary to link the Galaxy build container and the Postgres one. For
this, we need to create a dedicated bridge network so the `docker build` 
command can link to a running Postgres container:
```
docker network create gnet
```

2. Start the Postgres container with the newly created network and provide a
volume name on the host where the database files will be created if it does not
already exist and the data will be persisted there. Update the password as 
desired.
```
docker run -d --rm -e POSTGRES_DB=galaxy -e POSTGRES_USER=galaxydbuser \
-e POSTGRES_PASSWORD=42 -P --network gnet --name gpsql \
-v galaxydbvolume:/var/lib/postgresql/data postgres:10.6
```

To use a pre-built database (i.e., option (c) above), change the command to use 
a [bind volume](https://docs.docker.com/storage/bind-mounts/):
```
docker run -d --rm -e POSTGRES_DB=galaxy -e POSTGRES_USER=galaxydbuser \
-e POSTGRES_PASSWORD=42 -P --network gnet --name gpsql \
-v /tmp/docker/volumes/galaxy_postgres:/var/lib/postgresql/data postgres:10.6
```

3. If the password was updated in above command, correspondingly update the 
database connection line in `playbook.yml`:
```
  galaxy:
    database_connection: postgresql://galaxydbuser:42@gpsql/galaxy
```

4. Build the Galaxy image:
```
docker build --network gnet -t galaxy .
```
You may stop the Postgres container after the Galaxy image has been built.

## Run the container
To run the SQLite container and get an interactive shell, run the following:
```
docker run --rm -p 8080:8080 galaxy bash
uwsgi --yaml config/galaxy.yml
```

To start the Postgres version, first ensure that the Postgres container is 
running (refer to step 2 in the previous section). Then start the container and 
the Galaxy process:
```
docker run --rm --network gnet -p 8080:8080 galaxy bash
uwsgi --yaml config/galaxy.yml
```

Galaxy will be available on the host under `localhost:8080`.

***The following sections need revision:***

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

**Speed-up image build-time**

*This section is a draft description of an experimental feature.*

To improve development, image build time can be significantly reduced by using `Dockerfile.0`
together with `Dockerfile'.

Problem statement. During development, any change to playbook.yml (or the variables and/or files it
utilizes) results in a Docker cache miss, and the entire playbook is re-run. However, a few particularly
lenghty tasks do not result in any changes to the final image. 

Solution. Use `Dockerfile.0` to prebuild an intermediate-stage image that contains the Galaxy files
installed by running the playbook:

`docker build -f Dockerfile.0 --network gnet -t galaxy:image0 .`

Then, use `Dockerfile` to build the final image. To use the intermediate-stage image0:

`docker build --network gnet --build-arg BASE=galaxy:image0 -t galaxy:final .`

This will use the prebuilt image0 as the base for the build stage that runs the playbook. The
playbook will not re-clone the Git repository, reinstall dependencies, and rebuild the client. This
will result in a **much reduced** build time for subsequent builds.

Following is a brief description of the build stages in `Dockerfile.0` and `Dockerfile`.

Dockerfile.0: build base w/prebuilt galaxy (image0)
- FROM ubuntu
    - install build tools and ansible
    - run playbook

Dockerfile: build final image (image1)
- Stage 1:
    - FROM: ubuntu OR image0 (prebuilt by Dockerfile.0)
    - install build tools and ansible
    - run playbook
    - remove build artifacts + files not needed in container
- Stage 2:
    - FROM ubuntu
    - install python-virtualenv
    - create galaxy user+group
    - mkdir+chown galaxy directory
    - copy galaxy files from stage 1
    - finalize container (workdir, expose, user, path)
