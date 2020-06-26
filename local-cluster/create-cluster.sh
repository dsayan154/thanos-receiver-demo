#!/bin/sh
help() {
  echo "Usage: create-cluster <cluster-name> <config-file-path>"
}
if [ "$#" -lt 2 ]
then
  help
  exit 1
fi
clusterName=$1
configFilePath=$2
kind create cluster --name ${clusterName} --config ${configFilePath}
kubectl get pods -n kube-system
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
kubectl -n kube-system get pods | grep calico-node
