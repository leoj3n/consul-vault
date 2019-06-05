#!/usr/bin/env zsh

for i in {1..3}; do
  triton instance delete consulvault_consul-vault-service_${i}
done
