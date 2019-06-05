#!/usr/bin/env zsh

export COMPOSE_FILE='yml/triton-compose.yml'

./provision.sh ${@}
