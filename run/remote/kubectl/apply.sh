#!/usr/bin/env zsh

if [[ -z "${KUBECTL_NAMESPACE}" ]]; then
  print '${KUBECTL_NAMESPACE} not defined. Try: source ./run/env.source';
  exit 1
fi

for file in yaml/*.yaml; do
  cat "${file}" | \
    sed 's/\${KUBECTL_NAMESPACE}'"/${KUBECTL_NAMESPACE}/g" | \
    kubectl apply -f -
done
