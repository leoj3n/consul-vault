#!/usr/bin/env zsh

export COMPOSE_FILE='yml/kubectl-compose.yml'

./provision.sh "${@}"
