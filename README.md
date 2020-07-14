An Ansible playbook for building a Galaxy Docker image for Kubernetes.

The main purpose of this Docker image is to support Kubernetes, although the
image can be run standalone - by default with an sqlite database.
See [Galaxy Helm chart](https://github.com/galaxyproject/galaxy-helm) for how
to set up on Kubernetes.

## Setup the environment for building the image
1. Clone the playbook repo.

    ```
    git clone https://github.com/galaxyproject/galaxy-docker-k8s.git
    cd galaxy-docker-k8s
    ```

2. Make sure you have Ansible installed and then install/update required
   dependent Ansible roles.

    ```
    ansible-galaxy install -r requirements_roles.yml -p roles --force-with-deps
    ```

## Build and run container image (simple)

To build this container, run the following command, changing the tag
as desired. You will then be able to access Galaxy on port 8080.

```
docker build --no-cache --tag galaxy/galaxy-k8s:latest .
docker run -it --rm -p 8080:8080 galaxy/galaxy-k8s:latest
```

## Build and run a container image (full with Postgres database)
The default build above uses an sqlite database, although the image has the
necessary postgres drivers installed. In order to start Galaxy with a Postgres
database, we need to run a Postgres container in parallel.

1. It is necessary to link the Galaxy container and the Postgres one. For
   this, we need to create a dedicated bridge network so the `docker build`
   command can link to a running Postgres container. This needs to be done only
   once on a machine where you're building the image.

    ```
    docker network create gnet
    ```

2. Now we create a database that Galaxy will use. We need to provide a path on
   the host machine where the database files will be persisted (e.g.,
   `~/tmp_local/docker/volumes/pg_gxylatest`). If you are using a Mac to build
   the image, do not use the `/tmp` directory for this, as it is periodically
   cleaned by the OS, so your data will not be persisted properly. Note that we
   can reuse the same path/database multiple times. The first time we build the
   container, the database will be initialized by applying the latest Galaxy
   migration. Going forward, necessary migrations will be applied
   automatically. Note that this will change the structure of the database on
   the host. Finally, the version of the Postgres container should match the
   version of Postgres used by the Postgres chart specified in the requirements.

    ```
    docker run --rm -e POSTGRES_DB=galaxy -e POSTGRES_USER=galaxydbuser \
    -e POSTGRES_PASSWORD=42 --publish-all --network gnet --name gpsql \
    -v </local/path/to/database/dir>:/var/lib/postgresql/data postgres:11.6
    ```

3. Now we can build the Galaxy image against the psql image or skip this step
   if you have already built the image. First update `playbook.yml` to set
   `galaxy_manage_database` to `true`. If the database username and password
   were changed in the above step, correspondingly update the
   `database_connection` line. In a separate terminal tab, run the following
   command, changing the tag as desired.

    ```
    docker build --no-cache --network gnet --tag galaxy/galaxy-k8s:latest .
    ```

4. To test the build, first ensure that the Postgres container is
   running (refer to step 2 in the previous section). Then run the following:

    ```
    docker run -it --rm --network gnet -p 8080:8080 \
    -e GALAXY_CONFIG_OVERRIDE_DATABASE_CONNECTION="postgresql://galaxydbuser:42@gpsql/galaxy" \
    galaxy/galaxy-k8s:latest
    ```

   Galaxy will now be accessible on port 8080.

---

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

Next, create an additional 2 containers as job handlers with the following
command:

```
docker run -it --rm --network gnet galaxy bash
```

For each container, create an equivalent `job_conf.xml` file as in the web
handler container. Finally, star the web handlers with the following command,
suitably adjusting the server name as defined in the job conf:

```
/galaxy/server/scripts/galaxy-main -c config/galaxy.yml --server-name handler1
```

## Speed-up image build-time

To improve development, image build time can be significantly reduced by using
`Dockerfile.0` together with `Dockerfile`.

During development, any change to `playbook.yml` (or the variables and/or files
it utilizes) results in a Docker cache miss, and the entire playbook is re-run.
However, a few particularly lengthy tasks do not result in any changes to the
final image.

Solution. Use `Dockerfile.0` to pre-build an intermediate-stage image that
contains the Galaxy files installed by running the playbook:

`docker build -f Dockerfile.0 --network gnet -t galaxy:image0 .`

Then, use `Dockerfile` to build the final image. To use the intermediate-stage
image0:

`docker build --network gnet --build-arg BASE=galaxy:image0 -t galaxy:final .`

This will use the prebuilt image0 as the base for the build stage that runs the
playbook. The playbook will not re-clone the Git repository, reinstall
dependencies, and rebuild the client. This will result in a **much reduced**
build time for subsequent builds.

Following is a brief description of the build stages in `Dockerfile.0` and
`Dockerfile`.

Dockerfile.0: build base w/prebuilt galaxy (image0)
- FROM ubuntu
    - install build tools and Ansible
    - run playbook

Dockerfile: build final image (image1)
- Stage 1:
    - FROM: ubuntu OR image0 (prebuilt by Dockerfile.0)
    - install build tools and Ansible
    - run playbook
    - remove build artifacts + files not needed in container
- Stage 2:
    - FROM ubuntu
    - install python-virtualenv
    - create galaxy user+group
    - mkdir+chown galaxy directory
    - copy galaxy files from stage 1
    - finalize container (workdir, expose, user, path)

## Backup database to a SQL script file

1. Make sure your Postgres container is running (refer to step 2 of building a
   container image).

2. Exec into the Postgres container:
```
./scripts/pg-exec
```

3. Inside the container:
```
> cd /var/lib/postgresql/data
> pg_dump -U postgres -d galaxy > galaxy_dump.sql
```
The file is now located at `<path-to-bind-mount>/data`

For more information, refer to
[PostgreSQL documentation](https://www.postgresql.org/docs/10/app-pgdump.html).
