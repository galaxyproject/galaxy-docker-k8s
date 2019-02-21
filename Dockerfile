FROM ubuntu:18.04 as builder
ARG DEBIAN_FRONTEND=noninteractive 
ARG ROOT_DIR=/galaxy
ARG SERVER_DIR=$ROOT_DIR/server 

# Install misc. build tools
RUN apt-get -qq update && apt-get install -y --no-install-recommends \
      apt-transport-https \
      git \
      make \
#      npm \
#      nodejs \
      python-pip \
      python-virtualenv \ 
      software-properties-common \ 
      sudo \
      virtualenv \
      wget
#      wget \
#      && pip install requests \
#      && npm install -g yarn 

# Install ansible
RUN apt-add-repository -y ppa:ansible/ansible \
      && apt-get -qq update && apt-get install -y --no-install-recommends ansible

# Run ansible-galaxy
WORKDIR /tmp/ansible
COPY . .
RUN ansible-playbook -i localhost, playbook_localhost.yml

# remove node files
WORKDIR $SERVER_DIR
RUN rm -rf client/node_modules
RUN rm -rf .venv/bin/node
RUN rm -rf .venv/include/node
RUN rm -rf .venv/lib/node_modules
RUN rm -rf .venv/src/node*

# Remove .git and other unnecessary files
RUN rm -rf .git
RUN rm -rf .ci
RUN rm -rf doc
RUN rm -rf test
RUN rm -rf test-data

# Start new build stage for final image
FROM ubuntu:18.04
ARG DEBIAN_FRONTEND=noninteractive 
# Declare new var + redeclare old vars to use at this stage
# (TODO: move up when done with dev)
# NOTE: the value of GALAXY_USER is hardcoded in the COPY instruction below
ARG GALAXY_USER=galaxy
ARG ROOT_DIR=/galaxy
ARG SERVER_DIR=$ROOT_DIR/server 

# Install galaxy runtime requirements; clean up; add user+group; make dir; change perms
RUN apt-get -qq update && apt-get install -y --no-install-recommends python-virtualenv \
      && apt-get autoremove -y && apt-get clean \
      && rm -rf /var/lib/apt/lists/*  /tmp/* && rm -rf ~/.cache/ \
      && adduser --system --group $GALAXY_USER \
      && mkdir -p $SERVER_DIR && chown $GALAXY_USER:$GALAXY_USER $ROOT_DIR -R

WORKDIR $ROOT_DIR
# Copy galaxy files to final image
# The chown values MUST be hardcoded (see #35018 at github.com/moby/moby)
COPY --chown=galaxy:galaxy --from=builder $ROOT_DIR .
#
#WORKDIR $SERVER_DIR
#EXPOSE 8080
#USER $GALAXY_USER
#
## and run it!
#CMD . .venv/bin/activate && uwsgi --yaml config/galaxy.yml
