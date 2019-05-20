#!/bin/bash

# Install required ansible roles.

ansible-galaxy install -r requirements_roles.yml -p roles
