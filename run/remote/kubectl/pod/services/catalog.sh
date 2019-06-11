#!/usr/bin/env zsh

"${0:a:h:h}/exec.sh" "${1}" consul catalog services
