#!/usr/bin/env zsh

local dir="${0:a:h}"

provision() {
  print "RUNNING: ${dir}/provision.sh ${@}"
  "${dir}/provision.sh" "${@}"
}

print 'Triton provisioning using example data in ./secrets' && \
#  provision check && \
#  provision up && \
  provision secure \
    --gossip './secrets/gossip.key' \
    --ca-cert './secrets/CA/ca_cert.pem' \
    --tls-key './secrets/consul-vault.key.pem' \
    --tls-cert './secrets/consul-vault.cert.pem' && \
  provision init --keys 'example.asc' --threshold 1 && \
  provision unseal './secrets/example.asc.key' && \
  provision policy 'secret' './policies/example.hcl'
