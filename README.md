## POC TODOs
- [x] Provision local or GKE k8s cluster
- [x] create namespaces:
  - atom
  - ingestion
- [ ] install thanos receiver statefulset and other required k8s objects
- [ ] configure thanos recceiver to interact with gcs bucket
- [ ] configure thanos receive to behave as a cluster with replication
- [ ] configure thanos receiver for tenancy support
- [x] prepare a custom values.yaml for prometheus installation in atom namespace 
- [ ] install the prometheus to remote_write to thanos receiver
- [ ] measure the performance of write duration, query evaluation, thanos receiver space utilisation

## Creating a GKE cluster(terraform):
> Templates has been slightly modified from [Provision GKE Cluster with terraform](https://learn.hashicorp.com/terraform/kubernetes/provision-gke-cluster)
1. `cd gke-cluster/`
2. `terraform apply`
3. type "yes" to confirm apply
4. configure kubectl to connect to GKE cluster
  1. get the cluster name and region by `terraform output`
  2. generate the kubeconfig:
      `gcloud container clusters get-credentials poc-gke --region asia-south1`
5. deploy k8s dashboard:
  `kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml`
6. setup rbac for authenticating to k8s dashboard
  `kubectl apply -f k8s-dashboard-admin-rbac.yaml`
7. start a proxy server from another terminal
  `kubectl proxy`
8. generate a access-token for login to the k8s-dashboard
  `kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep service-controller-token | awk '{print $1}')`
9. access the dashboard from[here](http://127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)(http://127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)
10. enter the access token generated in step 8. to login
11. `kubectl apply -f poc.yaml`

#### Destroy Infra:
1. `terraform destroy`
