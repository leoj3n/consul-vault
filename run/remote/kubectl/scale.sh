#!/usr/bin/env zsh

"${0:a:h}/kubectl.sh" scale deploy --replicas="${1:-3}" "${2:-consul-vault-1}"
