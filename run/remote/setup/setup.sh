#!/usr/bin/env zsh

export COMPOSE_FILE='yml/docker-compose.yml'

./setup.sh ${@}
