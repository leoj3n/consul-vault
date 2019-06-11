#!/usr/bin/env zsh

local pod="${1}"
shift

"${0:a:h:h}/kubectl.sh" exec -it "${pod}" -- "${@}"
