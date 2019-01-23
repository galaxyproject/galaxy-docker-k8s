FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive 

WORKDIR /tmp/ansible
COPY . .

RUN apt-get -qq update && apt-get install -y --no-install-recommends \
# Install build tools
    apt-transport-https \
    software-properties-common \
    wget \
# Install galaxy runtime requirements
    python-virtualenv \
    virtualenv && \
# Install ansible
    apt-add-repository -y ppa:ansible/ansible && \
    apt-get -qq update && apt-get install -y --no-install-recommends ansible && \
# Run ansible-galaxy
    ansible-playbook -i localhost, playbook_localhost.yml && chown -R galaxy:galaxy /galaxy && \
# Clean up
    apt-get purge -y apt-transport-https software-properties-common wget ansible && \
    apt-get autoremove -y && apt-get clean && \
    rm -rf /var/lib/apt/lists/*  /tmp/* && rm -rf ~/.cache/ 

# Install client build tools 
# (combining this RUN stmt with the previous one will save 10M, and will cause misery for debugging)
RUN apt-get -qq update && apt-get install -y --no-install-recommends \
        git \
        make \
        nodejs \
        npm \
        python-pip && \
    cd /galaxy/server && \
## Build client
    pip install requests && \
    npm install -g yarn && \
    make client-production && \
# Clean up
    apt-get purge -y apt-transport-https software-properties-common \
        git \
        make \
        nodejs \
        npm \
        python-pip && \
    apt-get autoremove -y && apt-get clean && \
    rm -rf /var/lib/apt/lists/*  /tmp/* /galaxy/server/client/node_modules && rm -rf ~/.cache/ 

## TODO: pre-build conda. Check the rest.

WORKDIR /galaxy/server/
EXPOSE 80

USER galaxy
