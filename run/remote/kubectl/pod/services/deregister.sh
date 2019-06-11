#!/usr/bin/env zsh

"${0:a:h:h}/exec.sh" "${1}" curl -v -X PUT "http://127.0.0.1:8500/v1/agent/service/deregister/${2}"

#
# Use like:
#
#     ./deregister.sh consul-vault-1-6d57777b88-l6bzr passing node-node-1-5967ff9b9f-476bm
#
