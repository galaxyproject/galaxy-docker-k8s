# Stage-1 build: Install misc. build tools + ansible
FROM ubuntu:18.04 as builder
ARG DEBIAN_FRONTEND=noninteractive

RUN set -ex; \
    apt-get -qq update; \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        git \
        make \
        python-virtualenv \
        software-properties-common \
        && apt-add-repository -y ppa:ansible/ansible \
        && apt-get -qq update && apt-get install -y --no-install-recommends ansible \
        && apt-get autoremove -y && apt-get clean \
        && rm -rf /var/lib/apt/lists/*
