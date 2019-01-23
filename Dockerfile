FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive 

RUN apt-get -qq update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    git \
    make \
    nodejs \
    npm \
    python-pip \
    python-virtualenv \
    software-properties-common \
    virtualenv 

RUN apt-add-repository -y ppa:ansible/ansible && \
    apt-get -qq update && apt-get install -y --no-install-recommends ansible && \
    apt-get purge -y software-properties-common 

WORKDIR /tmp/ansible
COPY . .
RUN ansible-playbook -i localhost, playbook_localhost.yml && chown -R galaxy:galaxy /galaxy 

WORKDIR /galaxy/server

# Build client
RUN pip install requests && \
    npm install -g yarn && \
    make client-production

## Cleanup
# TODO: cleanup: remove build tools we don't need
# TODO: pre-build conda. Check the rest.

EXPOSE 80

USER galaxy
