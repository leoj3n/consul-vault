#!/usr/bin/env zsh

local pod="${1}"
shift

"${0:a:h}/exec.sh" "${pod}" bash -c 'rm -rf /data/services /data/checks && containerpilot -reload'
