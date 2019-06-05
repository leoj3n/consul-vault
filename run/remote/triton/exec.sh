#!/usr/bin/env zsh

triton-docker exec -it consulvault_consul-vault-service_${@}

#
# Use like:
#
#   ./run/remote/triton/exec.sh 1 sh
#
