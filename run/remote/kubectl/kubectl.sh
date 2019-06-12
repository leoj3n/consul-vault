#!/usr/bin/env zsh

kubectl --namespace "${KUBECTL_NAMESPACE:-default}" ${@}
