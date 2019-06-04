#!/usr/bin/env zsh

local 'service' 'cache'

service='consul-vault-service'
vared -p 'Docker compose service name: ' 'service'

if read -q "?Bust the cache [y/N]? "; then
  cache='--no-cache'
else
  unset cache
fi

print
"${0:a:h:h}/local-compose.sh" build ${cache} "${service}" "${@}"
