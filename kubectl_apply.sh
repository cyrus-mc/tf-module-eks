#!/bin/bash

TMP_DIR=`mktemp -d`

KUBECONFIG=$1
MANIFEST=$2

# write out our kubeconfig
echo $KUBECONFIG > ${TMP_DIR}/kubeconfig
# write out our manifest
echo $MANIFEST > ${TMP_DIR}/manifest.json

echo $KUBECONFIG
for i in {1..5}; do
  kubectl apply -f ${TMP_DIR}/manifest.json --kubeconfig ${TMP_DIR}/kubeconfig
  RETURN=$?
  if [[ $RETURN -eq 0 ]]; then
    break
  fi
  sleep 10
done

exit $RETURN

