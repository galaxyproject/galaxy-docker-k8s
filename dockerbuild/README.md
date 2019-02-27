Dockerfile.1: build base for final image
- FROM ubuntu:18.04
- install python-virtualenv

Dockerfile.2: build intermediate base w/prebuilt galaxy
- FROM ubuntu:18.04
- install build tools and ansible
- run playbook

Dockerfile.3: build base for final image, then final image 
- FROM: image-2 as builder
- rerun playbook
- remove build artifacts and unnecessary files
- FROM: image-1
- adduser
- mkdir + chown
- copy galaxy files from builder
- prepare runtime (workdir, expose, user, path)
