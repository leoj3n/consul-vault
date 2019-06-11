#!/usr/bin/env zsh

kubectl --namespace "${KUBE_NAMESPACE:-default}" ${@}
