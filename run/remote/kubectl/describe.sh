#!/usr/bin/env zsh

"${0:a:h}/kubectl.sh" describe "${@}"

#
# Use like:
# 
#   ./describe.sh limits
#
