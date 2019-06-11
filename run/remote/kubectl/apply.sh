#!/usr/bin/env zsh

for file in yaml/*.yaml; do
  cat "${file}" | \
    sed 's/\${KUBE_NAMESPACE}'"/${KUBE_NAMESPACE}/g" | \
    kubectl apply -f -
done
