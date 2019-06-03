#!/usr/bin/env zsh

docker-compose --project-name 'consul-vault' --file 'yml/local-compose.yml' ${@}
