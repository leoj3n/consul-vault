#!/usr/bin/env zsh

"${0:a:h:h}/kubectl.sh" delete pods "${@}"
