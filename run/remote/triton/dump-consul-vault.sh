#!/usr/bin/env zsh

"${0:a:h}/exec.sh" "${1:-1}" consul kv get -recurse vault/logical
