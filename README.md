## POC TODOs
- [x] Provision local or GKE k8s cluster
- [x] create namespaces:
  - atom
  - ingestion
- [x] install thanos receiver statefulset and other required k8s objects
- [x] configure thanos receiver to interact with gcs bucket
- [x] configure thanos receive to persist data in PVs
- [ ] configure thanos receive to behave as a cluster with replication
- [x] prepare a custom values.yaml for prometheus installation in atom namespace 
- [ ] install the prometheus to remote_write to thanos receiver
- [ ] measure the performance of write duration, query evaluation, thanos receiver space utilisation

## Create POC infra on k8s
1. `kubectl apply -f poc-ns.yaml`
2. `kubectl apply -f poc-sa.yaml -n ingestion`
3. `kubectl apply -f poc-cm.yaml -n ingestion`
4. `kubectl -n ingestion create secret generic gcs-bucket-credentials --from-file=gcs-bucket-secret.yaml`
5. `kubectl apply -f poc-sts.yaml -n ingestion`
6. `kubectl apply -f poc-svc.yaml -n ingestion`
7. `helm upgrade --install prometheus stable/prometheus --namespace atom -f values.yaml --debug`
