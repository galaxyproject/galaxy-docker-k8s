# Declare+assign variables before first FROM to use in all build stages.
# NOTE: the value of GALAXY_USER must be also hardcoded in the COPY instruction in the final stage
ARG DEBIAN_FRONTEND=noninteractive
ARG ROOT_DIR=/galaxy
ARG SERVER_DIR=$ROOT_DIR/server
ARG GALAXY_USER=galaxy

FROM ubuntu:18.04 as builder
ARG DEBIAN_FRONTEND
ARG ROOT_DIR
ARG SERVER_DIR
ARG GALAXY_USER

# Install misc. build tools
RUN apt-get -qq update && apt-get install -y --no-install-recommends \
      apt-transport-https \
      git \
      make \
      python-virtualenv \
      software-properties-common

# Install ansible
RUN apt-add-repository -y ppa:ansible/ansible \
      && apt-get -qq update && apt-get install -y --no-install-recommends ansible

# Run ansible-galaxy
WORKDIR /tmp/ansible
COPY . .
RUN ansible-playbook -i localhost, playbook_localhost.yml

# remove files not needed in production (node, .git, etc...)
WORKDIR $SERVER_DIR
RUN rm -rf client/node_modules .venv/bin/node .venv/include/node .venv/lib/node_modules \
      .venv/src/node* .git .ci doc test test-data

# Start new build stage for final image
FROM ubuntu:18.04
ARG DEBIAN_FRONTEND
ARG ROOT_DIR
ARG SERVER_DIR
ARG GALAXY_USER

# Install galaxy runtime requirements; clean up; add user+group; make dir; change perms
RUN apt-get -qq update && apt-get install -y --no-install-recommends python-virtualenv \
      && apt-get autoremove -y && apt-get clean \
      && rm -rf /var/lib/apt/lists/*  /tmp/* && rm -rf ~/.cache/ \
      && adduser --system --group $GALAXY_USER \
      && mkdir -p $SERVER_DIR && chown $GALAXY_USER:$GALAXY_USER $ROOT_DIR -R

WORKDIR $ROOT_DIR
# Copy galaxy files to final image
# The chown value MUST be hardcoded (see #35018 at github.com/moby/moby)
COPY --chown=galaxy:galaxy --from=builder $ROOT_DIR .

WORKDIR $SERVER_DIR
EXPOSE 8080
USER $GALAXY_USER
ENV PATH="$SERVER_DIR/.venv/bin:${PATH}"

# and run it!
#CMD . .venv/bin/activate && uwsgi --yaml config/galaxy.yml
