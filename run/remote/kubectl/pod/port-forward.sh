#!/usr/bin/env zsh

"${0:a:h:h}/kubectl.sh" port-forward "${1}" "${2:-1337:8500}"
