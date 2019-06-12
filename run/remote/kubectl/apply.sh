#!/usr/bin/env zsh

for file in yaml/*.yaml; do
  cat "${file}" | \
    sed 's/\${KUBECTL_NAMESPACE}'"/${KUBECTL_NAMESPACE}/g" | \
    kubectl apply -f -
done
