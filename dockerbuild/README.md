Dockerfile.0: build base w/prebuilt galaxy (image0)
- FROM ubuntu
    - install build tools and ansible
    - run playbook

Dockerfile.1: build final image (image1)
- Stage 1: 
    - FROM ubuntu
    - install python-virtualenv

- Stage 2: 
    - FROM ubuntu
    - install build tools and ansible

- Stage 3:
    - FROM: ubuntu OR image0 (prebuilt by Dockerfile.0)
    - run playbook
    - remove build artifacts + files not needed in container

- Stage 4:
    - FROM: stage 1
    - create galaxy user+group
    - mkdir+chown galaxy directory
    - copy galaxy files from stage 3
    - finalize container (workdir, expose, user, path)
