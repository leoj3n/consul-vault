#!/usr/bin/env zsh

"${0:a:h:h}/exec.sh" "${1}" curl http://127.0.0.1:8500/v1/agent/checks | json -Ma 'value.Status' 'value.ServiceID'

#
# Use like:
#
#     ./get.sh consul-vault-1-6d57777b88-l6bzr
#
