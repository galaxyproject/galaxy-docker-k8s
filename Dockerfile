# RUN statements in the 'builder' image are combined into logical groups for
# simplifying development/debugging. This image is not included in the final
# image, so the extra size is not an issue.

ARG ROOT_DIR=/galaxy
ARG GALAXY_SERVER_DIR=$ROOT_DIR/server 
ARG GALAXY_USER=galaxy

FROM ubuntu:18.04 as builder
ARG DEBIAN_FRONTEND=noninteractive 
ARG ROOT_DIR
ARG GALAXY_SERVER_DIR
ARG GALAXY_USER

# Install misc. build tools
RUN apt-get -qq update && apt-get install -y --no-install-recommends \
      apt-transport-https software-properties-common wget python-virtualenv virtualenv  

# Install ansible and sudo (sudo required by ansible-galaxy role)
RUN apt-add-repository -y ppa:ansible/ansible \
      && apt-get -qq update && apt-get install -y --no-install-recommends ansible sudo 

# Install client build tools 
RUN apt-get -qq update && apt-get install -y --no-install-recommends \
      git make nodejs npm python-pip \
      && pip install requests && npm install -g yarn 

# Run ansible-galaxy
WORKDIR /tmp/ansible
COPY . .
RUN ansible-playbook -i localhost, playbook_localhost.yml


# Build the client; remove node_modules
WORKDIR $GALAXY_SERVER_DIR
RUN make client-production && rm $GALAXY_SERVER_DIR/client/node_modules -rf

#Run common startup to prefetch wheels
RUN ./scripts/common_startup.sh

# Start new build stage for final image
FROM ubuntu:18.04
ARG DEBIAN_FRONTEND=noninteractive 
ARG ROOT_DIR
ARG GALAXY_SERVER_DIR
ARG GALAXY_USER

# Install galaxy runtime requirements; clean up; add user+group; make dir; change perms
RUN apt-get -qq update && apt-get install -y --no-install-recommends python-virtualenv \
      && apt-get autoremove -y && apt-get clean \
      && rm -rf /var/lib/apt/lists/*  /tmp/* && rm -rf ~/.cache/ \
      && adduser --system --group $GALAXY_USER \
      && mkdir -p $GALAXY_SERVER_DIR && chown $GALAXY_USER:$GALAXY_USER $ROOT_DIR -R

# Copy galaxy files to final image TODO: use variables 
WORKDIR $GALAXY_SERVER_DIR
COPY --chown=galaxy:galaxy --from=builder $GALAXY_SERVER_DIR .

EXPOSE 8080
USER $GALAXY_USER

## [WIP]
## start the container, then run: ". .venv/bin/activate && uwsgi --yaml config/galaxy.yml --daemonize tmp.log"
#
## [WIP: not needed]
# CMD sh run.sh --skip-wheels --skip-client-build --skip-tool-dependency-initialization
