# RUN statements in the 'builder' image are combined into logical groups for
# simplifying development/debugging. This image is not included in the final
# image, so the extra size is not an issue.

FROM ubuntu:18.04 as builder
ARG DEBIAN_FRONTEND=noninteractive 

# Install misc. build tools
RUN apt-get -qq update && apt-get install -y --no-install-recommends \
      apt-transport-https software-properties-common wget python-virtualenv virtualenv 

# Install ansible
RUN apt-add-repository -y ppa:ansible/ansible \
      && apt-get -qq update && apt-get install -y --no-install-recommends ansible 

# Run ansible-galaxy
WORKDIR /tmp/ansible
COPY . .
RUN ansible-playbook -i localhost, playbook_localhost.yml

# Install client build tools 
RUN apt-get -qq update && apt-get install -y --no-install-recommends \
      git make nodejs npm python-pip \
      && pip install requests && npm install -g yarn 

# Build the client
WORKDIR /galaxy/server/
RUN make client-production \
      && rm /galaxy/server/client/node_modules -rf

# Run common startup to prefetch wheels
RUN ./scripts/common_startup.sh

# Start new build stage for final image
FROM ubuntu:18.04
ARG DEBIAN_FRONTEND=noninteractive 

# Install galaxy runtime requirements; clean up; add user+group; make dir; change perms
RUN apt-get -qq update && apt-get install -y --no-install-recommends python-virtualenv \
      && apt-get autoremove -y && apt-get clean \
      && rm -rf /var/lib/apt/lists/*  /tmp/* && rm -rf ~/.cache/ \
      && adduser --system --group galaxy \
      && mkdir -p /galaxy/server && chown galaxy:galaxy /galaxy -R

# Copy galaxy files to final image
WORKDIR /galaxy/server/
COPY --chown=galaxy:galaxy --from=builder /galaxy/server .

EXPOSE 8080
USER galaxy

CMD sh run.sh --skip-wheels --skip-client-build --skip-tool-dependency-initialization
