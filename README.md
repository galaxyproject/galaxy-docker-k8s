An Ansible playbook for building a Galaxy container for Kubernetes.

## Setup
1. Clone the playbook repo
```
git clone https://github.com/CloudVE/galaxy-kube-playbook.git
cd galaxy-kube-playbook
```

2. Install required/dependent Ansible roles
```
ansible-galaxy install -r requirements_roles.yml -p roles
```

## Build a container image
1. Run the following command to build a Docker container
```
docker build -t galaxy .
```
