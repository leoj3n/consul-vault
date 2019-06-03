#!/usr/bin/env zsh

"${0:a:h:h}/docker-compose.sh" --file './yml/dev-compose.yml' "${@}"
