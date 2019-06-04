#!/usr/bin/env zsh

local setup="${0:a:h}/setup.sh"

"${setup}" check && \
  "${setup}" up && \
  "${setup}" secure \
    --tls-key './secrets/consul-vault.key.pem' \
    --tls-cert './secrets/consul-vault.cert.pem' \
    --ca-cert './secrets/CA/ca_cert.pem' \
    --gossip './secrets/gossip.key' && \
  "${setup}" init --keys 'example.asc' --threshold 1 && \
  "${setup}" unseal './secrets/example.asc.key' && \
  "${setup}" policy 'secret' './policies/example.hcl'
