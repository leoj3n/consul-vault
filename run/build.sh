#!/usr/bin/env zsh

service='consul-vault'
vared -p 'Docker compose service name: ' service

if read -q "?Bust the cache [y/N]? "; then
  print
  docker-compose --file local-compose.yml build --no-cache "${service}"
else
  print
  docker-compose --file local-compose.yml build "${service}"
fi

