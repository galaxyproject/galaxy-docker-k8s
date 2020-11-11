An Ansible playbook used when creating a minimal docker image for Galaxy.

This playbook uses the [ansible-galaxy](https://github.com/galaxyproject/ansible-galaxy)
role, and defines settings suitable for running a minimal build of Galaxy, by default
using a local sqlite database. This minimalist image is also used in the Kubernetes
distribution of Galaxy. See [Galaxy Helm chart](https://github.com/galaxyproject/galaxy-helm)
for how to set up on Kubernetes.
See [Docker Galaxy Stable](https://github.com/bgruening/docker-galaxy-stable) for a
fully-fledged, single container installation of Galaxy.

## Building a Galaxy docker image

    ```
    git clone https://github.com/galaxyproject/galaxy.git
    docker build . --tag galaxy/galaxy:latest
    docker run -it --rm -p 8080:8080 galaxy/galaxy:latest
    ```

## Extending the image

### Method 1

    Build the image with a customized playbook. Your customized playbook can
    override all settings as required.

    ```
    git clone https://github.com/galaxyproject/galaxy.git
    docker build --build-arg GALAXY_PLAYBOOK_REPO=https://github.com/myrepo/galaxy-custom . -t galaxy/galaxy:custom
    ```

### Method 2

    Extend the mimimal image and add your customizations on top.

    ```
    FROM galaxy/galaxy:latest

    # switch to root
    USER root

    RUN apt-get -qq update && apt-get install -y --no-install-recommends gridengine-drmaa1.0

    # switch back to galaxy
    USER galaxy

    RUN /galaxy/server/.venv/bin/pip install drmaa
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
