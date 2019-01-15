FROM ubuntu:18.04

RUN apt-get -qq update && apt-get install --no-install-recommends -y apt-transport-https  software-properties-common && \
    apt-add-repository -y ppa:ansible/ansible && \
    apt-get -qq update && \
    apt-get -qq install ansible && \
    apt-get purge -y software-properties-common && \
    mkdir /tmp/ansible && touch /etc/sudoers
WORKDIR /tmp/ansible
COPY . .
RUN ansible-playbook -i localhost, playbook_localhost.yml
