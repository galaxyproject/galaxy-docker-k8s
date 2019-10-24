An Ansible playbook for building a Galaxy Docker image for Kubernetes.

Note that this Galaxy Docker image is not intended to be run standalone but
instead used as part of a container orchestration system, namely Kubernetes.
See [Galaxy Helm chart](https://github.com/galaxyproject/galaxy-helm) for how
to go about doing this.

## Setup the environment for building the image
1. Clone the playbook repo.

    ```
    git clone https://github.com/CloudVE/galaxy-docker-k8s.git
    cd galaxy-docker-k8s
    ```

2. Make sure you have Ansible installed and then install/update required
   dependent Ansible roles.

    ```
    ansible-galaxy install -r requirements_roles.yml -p roles --force-with-deps
    ```

## Build a container image (simple)

The next section contains instructions for a full container image that is
testable when deployed alongside a Postgres container and may be useful for
producing compatible database dumps if needed. However, the Helm chart is fully
functional when run from an image built with a simple standalone ``docker
build``. To build this container, run the following command, changing the tag
as desired.

```
docker build --no-cache --tag galaxy/galaxy-k8s:19.09 .
```

## Build a container image (full with Postgres database)
We will build the container configured to use an external PostgreSQL database
so we need to run a Postgres container in parallel to the one building the
Galaxy image.

1. It is necessary to link the Galaxy build container and the Postgres one. For
   this, we need to create a dedicated bridge network so the `docker build`
   command can link to a running Postgres container. This needs to be done only
   once on a machine where you're building the image.

    ```
    docker network create gnet
    ```

2. Now we create a database that Galaxy will use. We need to provide a path on
   the host machine where the database files will be persisted (e.g.,
   `~/tmp_local/docker/volumes/pg_gxy19.09`). If you are using a Mac to build
   the image, do not use the `/tmp` directory for this, as it is periodically
   cleaned by the OS, so your data will not be persisted properly. Note that we
   can reuse the same path/database multiple times. The first time we build the
   container, the database will be initialized by applying all of Galaxy's
   migrations and going forward it can just be reused without having to perform
   the migrations. When the version of Galaxy being built requires a newer
   database migration, it will be automatically applied by Galaxy's startup
   process. Note that this will change the structure of the database on the
   host.

    ```
    docker run --rm -e POSTGRES_DB=galaxy -e POSTGRES_USER=galaxydbuser \
    -e POSTGRES_PASSWORD=42 --publish-all --network gnet --name gpsql \
    -v </local/path/to/database/dir>:/var/lib/postgresql/data postgres:11.3
    ```

3. Now we can build the Galaxy image. First update `playbook.yml` to set
   `galaxy_manage_database` to `true`. If the database username and password
   were changed in the above step, correspondingly update the
   `database_connection` line. In a separate terminal tab, run the following
   command, changing the tag as desired.

    ```
    docker build --no-cache --network gnet --tag galaxy/galaxy-k8s:19.09 .
    ```

4. (optional) To create a dump of the database, run the following set of
   commands. Once we have a dump, we can update the Helm chart with its
   content.

    ```
    1. Exec into the Postgres container
    2. Run the following within the container:
        pg_dump -U galaxydbuser -d galaxy > /var/lib/postgresql/data/dump.sql
    3. On the host, the dump will be in located in the folder that was mounted
       into the Postgres container (eg, ~/tmp_local/docker/volumes/pg_gxy19.09)
    4. Place the contents of the dump into the Helm chart restore script, after
       EOSQL, https://github.com/galaxyproject/galaxy-helm/blob/master/galaxy/files/conf.d/init2_restore.sh.
    ```

   You may stop the Postgres container after the Galaxy image has been built.

## Run the container
As stated earlier, this container is not intended to be used for running Galaxy
as is but should be used as part of a Kubernetes deployment. However, to test
that the build was successful, it is possible to start Galaxy in limited
capacity. If you are running Docker for Desktop, you will need to add Nginx
ingress to your Kubernetes: https://kubernetes.github.io/ingress-nginx/deploy/

To test the build, first ensure that the Postgres container is
running (refer to step 2 in the previous section). Then run the following:

```
docker run -it --rm --network gnet -p 8080:8080 galaxy/galaxy-k8s:19.09 bash
```

Before we can start the Galaxy process, we need to update `config/galaxy.yml`
file to remove `data_manager_config_file` and `shed_tool_data_table_config`
entries as those files do not exist on the minimal image yet the
`galaxy-ansible` role adds them into the default config. Then run

```
uwsgi --yaml config/galaxy.yml
```

Galaxy will be available on the host under `http://localhost:8080/`.


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
