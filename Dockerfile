# Stage 1:
# - base: ubuntu (default) OR prebuilt image0
# - install build tools
# - run playbook (image0 avoids rerunning lengthy tasks)
# - remove build artifacts + files not needed in container
# Stage 2:
# - install python-virtualenv
# - create galaxy user + group + directory
# - copy galaxy files from stage 1
# - finalize container (set path, user...)

# Init ARGs
ARG ROOT_DIR=/galaxy
ARG SERVER_DIR=$ROOT_DIR/server
# For much faster build time override this with image0 (Dockerfile.0 build):
#   docker build --build-arg BASE=<image0 name>...
ARG BASE=ubuntu:18.04
# NOTE: the value of GALAXY_USER must be also hardcoded in COPY in final stage
ARG GALAXY_USER=galaxy

# Stage-1
FROM $BASE AS stage1
ARG DEBIAN_FRONTEND=noninteractive
ARG SERVER_DIR

# Install build dependencies + ansible
RUN set -xe; \
    apt-get -qq update && apt-get install -y --no-install-recommends \
        apt-transport-https \
        git \
        make \
        python-virtualenv \
        python-dev \
        software-properties-common \
        ssh \
        gcc \
        libpython2.7 \
    && apt-add-repository -y ppa:ansible/ansible \
    && apt-get -qq update && apt-get install -y --no-install-recommends \
        ansible \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/*

# Remove context from previous build; copy current context; run playbook
WORKDIR /tmp/ansible
RUN rm -rf *
COPY . .
RUN ansible-playbook -i localhost, playbook.yml -vv

# Remove build artifacts + files not needed in container
WORKDIR $SERVER_DIR
RUN rm -rf \
        .ci \
        .git \
        .venv/bin/node \
        .venv/include/node \
        .venv/lib/node_modules \
        .venv/src/node* \
        client/node_modules \
        doc \
        test \
        test-data

# Stage-2
FROM ubuntu:18.04
ARG DEBIAN_FRONTEND=noninteractive
ARG ROOT_DIR
ARG SERVER_DIR
ARG GALAXY_USER

# Install python-virtualenv
RUN set -xe; \
    apt-get -qq update && apt-get install -y --no-install-recommends \
        python-virtualenv \
        vim \
        libpython2.7 \
        curl \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/*

# Create Galaxy user, group, directory; chown
RUN set -xe; \
      adduser --system --group $GALAXY_USER \
      && mkdir -p $SERVER_DIR \
      && chown $GALAXY_USER:$GALAXY_USER $ROOT_DIR -R

WORKDIR $ROOT_DIR
# Copy galaxy files to final image
# The chown value MUST be hardcoded (see #35018 at github.com/moby/moby)
COPY --chown=galaxy:galaxy --from=stage1 $ROOT_DIR .

WORKDIR $SERVER_DIR
EXPOSE 8080
USER $GALAXY_USER

ENV PATH="$SERVER_DIR/.venv/bin:${PATH}"

# [optional] to run:
#CMD uwsgi --yaml config/galaxy.yml
