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
We will build the container configured to use an external PostgreSQL database
so we need to run a Postgres container in parallel to the one building the
Galaxy image.

1. It is necessary to link the Galaxy build container and the Postgres one. For
   this, we need to create a dedicated bridge network so the `docker build`
   command can link to a running Postgres container:
    ```
   docker network create gnet
   ```

2. In this step we will create a database that Galaxy will use. You can do so by
   running by running a `docker run` command directly or by running a couple of
   convenience scripts. For either option, you will need to provide a path to a
   path on the host machine where the database files will be created (if it does
   not already exist) and the data will be persisted. If you are using a Mac to
   build the image, do not use the `/tmp` directory, as it is periodically
   cleaned by the OS, so your data will not be persisted properly.

   2.1 Running the native `docker` command
   ```
   docker run -d --rm -e POSTGRES_DB=galaxy -e POSTGRES_USER=galaxydbuser \
   -e POSTGRES_PASSWORD=42 -P --network gnet --name gpsql \
   -v </local/path/to/database>:/var/lib/postgresql/data postgres:10.6
   ```

   2.2 Using convenience scripts
   To use these scripts, you will need to have `psql` command installed locally.
   Then, tun `pg-run.sh` to start the Postgres container with the newly created
   network :
   ```
   ./scripts/pg-run.sh <path-to-directory>
   ```

   If you would like to create the Galaxy database as a dedicated step (as
   opposed to as part of the overall build process), run `pg-galaxy-init.sh` to create
   the galaxy database user and database, and change ownership and assign
   appropriate privileges, providing the port number of the Postgres container.
   ```
   ./scripts/pg-galaxy-init.sh <port-number>
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
   ./scripts/pg-restore.sh <port-number> < <sql-dump-file>
   ```

3. Now we can build the Galaxy image. If the password was updated in the above
   step, correspondingly update the database connection line in `playbook.yml`.
   Run `galaxy-build.sh` to build the Galaxy image, providing an image name and
   an image tag:
   ```
   ./scripts/galaxy-build.sh <image-name> <image-tag>
   ```

   You may stop the Postgres container after the Galaxy image has been built.

## Run the container
To run the container, first ensure that the Postgres container is
running (refer to step 2 in the previous section). Then run `galaxy-run.sh`,
providing the image name and an image tag:
```
./scripts/galaxy-run.sh <image-name> <image-tag>
```

Optionally, you may run `galaxy-run-root.sh`, which gives you root access to the
container (should you need it).

Then exec into the galaxy container:
```
> docker exec -it <galaxy-container-id> bash
```
and start the galaxy process (source the virtual env, then call `uwsgi`):
```
> . .venv/bin/activate
> uwsgi --yaml config/galaxy.yml
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
`Dockerfile.0` together with `Dockerfile'.

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
