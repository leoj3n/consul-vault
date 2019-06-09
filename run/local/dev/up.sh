#!/usr/bin/env zsh

"${0:a:h}/dev-compose.sh" up --detach "${@}"

if ! [[ "${@}" =~ '--build' ]]; then
  print
  print 'Pass --build to copy over new file changes.'
fi

print
print 'Consul UI:'
print
print '  http://0.0.0.0:8500'
print
print 'Vault UI:'
print
print '  http://0.0.0.0:8200'
print
print 'Vault root token:'
print
print "  $(docker exec consulvault_consul-vault_1 cat /root/.vault-token)"
