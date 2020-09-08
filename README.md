# Introduction

 Hey there! If you are reading this blog post, then I guess you are already aware of [Prometheus](https://prometheus.io/) and how it helps us in monitoring distributed systems like [Kubernetes](https://kubernetes.io/). And if you are familiar with [Prometheus](https://prometheus.io/), then chances are that you have come across the name called Thanos. [Thanos](https://thanos.io/) is an popular OSS which helps enterprises acheive a HA [Prometheus](https://prometheus.io/) setup with long-term storage capabilities.
 One of the common challenges of distributed monitoring is to implement multi-tenancy. [Thanos Receiver](https://thanos.io/v0.14/components/receive/) is Thanos component designed to address this common challenge. [Receiver](https://thanos.io/v0.14/components/receive/) was part of Thanos for a long time, but it was EXPERIMENTAL. Recently, [Thanos](https://thanos.io) went GA with the [Receiver](https://thanos.io/v0.14/components/receive/) component. 

# Motivation
 We tried this component with one of our clients, it worked well. However, due to lack of documentation, the setup wasn't as smooth as we would have liked it to be. Purpose of this blog post is to lay out a simple guide for those who are looking forward to create a multi-tenant monitoring setup using Prometheus and Thanos Receive. In this blog post we will try to use [Thanos Reciever](https://thanos.io/v0.14/components/receive) to acheive a simple multi-tenant monitoring setup where prometheus can be a near stateless component on the tenant side.

# A few words on Thanos Receiver
 [Receiver](https://thanos.io/v0.14/components/receive/) is a Thanos component that can accept [remote write](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write) requests from any Prometheus instance and store the data in its local TSDB, optionally it can upload those TSDB blocks to an [object storage](https://thanos.io/v0.14/thanos/storage.md/) like S3 or GCS at regular intervals. Receiver does this by implementing the [Prometheus Remote Write API](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write). It builds on top of existing Prometheus TSDB and retains their usefulness while extending their functionality with long-term-storage, horizontal scalability, and downsampling. It exposes the StoreAPI so that Thanos Queriers can query received metrics in real-time. 
## Multi-tenancy
 Thanos Receiver supports multi-tenancy. It accepts Prometheus remote write requests, and writes these into a local instance of Prometheus TSDB. The value of the HTTP header("THANOS-TENANT") of the incoming request determines the id of the tenant Prometheus. To prevent data leaking at the database level, each tenant has an individual TSDB instance, meaning a single Thanos receiver may manage multiple TSDB instances. Once the data is successfully committed to the tenant’s TSDB, the requests return successfully. Thanos Receiver also supports multi-tenancy by exposing labels which are similar to Prometheus [external labels](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#configuration-file).
## Hashring config file
 If we want features like load-balancing and data replication, we can run multiple instances of Thanos receiver as a part of a single hashring. The receiver instances within the same hashring become aware of their peers through a hashring config file. Following is an example of a hashring config file.
 ```
 [
    {
        "hashring": "tenant-a",
        "endpoints": ["tenant-a-1.metrics.local:19291/api/v1/receive", "tenant-a-2.metrics.local:19291/api/v1/receive"],
        "tenants": ["tenant-a"]
    },
    {
        "hashring": "tenants-b-c",
        "endpoints": ["tenant-b-c-1.metrics.local:19291/api/v1/receive", "tenant-b-c-2.metrics.local:19291/api/v1/receive"],
        "tenants": ["tenant-b", "tenant-c"]
    },
    {
        "hashring": "soft-tenants",
        "endpoints": ["http://soft-tenants-1.metrics.local:19291/api/v1/receive"]
    }
 ]
 ```
 - Soft tenancy -  If a hashring specifies no explicit tenants, then any tenant is considered a valid match; this allows for a cluster to provide soft-tenancy. Requests whose tenant ID matches no other hashring explicitly, will automatically land in this soft tenancy hashring. All incoming remote write requests which don't set the tenant header in the HTTP request, fall under soft tenancy and default tenant ID(configurable through the flag --receive.default-tenant-id) is attached to their metrics.
 - Hard tenancy - Hard tenants must set the tenant header in every HTTP request for remote write. Hard tenants in the Thanos receiver are configured in a hashring config file. Changes to this configuration must be orchestrated by a configuration management tool. When a remote write request is received by a Thanos receiver, it goes through the list of configured hard tenants. A hard tenant also has the number of associated receiver endpoints belonging to it. <br>
 **P.S: A remote write request can be initially received by any receiver instance, however, will only be dispatched to receiver endpoints that correspond to that hard tenant.** 

# Architecture
In this blog post, we are trying to implement the following architecture. 
<p align="center">
<img alt="A simple multi-tenancy model with thanos receive" src="./images/arch/thanos-receive-multi-tenancy.png"><br>
A simple multi-tenancy model with thanos receive
</p>

Brief overview on the above architecture:
- We have 3 Prometheuses running in namespaces: `sre`, `tenant-a` and `tenant-b` respectively.
- The Prometheus in `sre` namespace is demonstrated as a soft-tenant therefore it does not set any additional HTTP headers to the remote write requests.
- The Prometheuses in `tenant-a` and `tenant-b` are demonstrated as hard tenants. The NGINX servers in those respective namespaces are used for setting tenant header for the tenant Prometheus.
- From security point of view we are only exposing the thanos receive statefulset responsible for the soft-tenant(sre prometheus).
- For both Thanos receiver statefulsets(soft and hard) we are setting a [replication factor=2](https://github.com/dsayan154/thanos-receiver-demo/blob/fbaf6e4cfdf96c0840b71029ed2d51ca1c8ca94e/manifests/thanos-receive-hashring-0.yaml#L35). This would ensure that the incoming data get replicated between two receiver pods.
- The remote write request which is received by the [soft tenant receiver](https://github.com/dsayan154/thanos-receiver-demo/blob/master/manifests/thanos-receive-default.yaml) instance is forwarded to the [hard tenant thanos receiver](https://github.com/dsayan154/thanos-receiver-demo/blob/master/manifests/thanos-receive-hashring-0.yaml). This routing is based on the hashring config.

The above architecture obviously misses few features that one would also expect from a multi-tenant architecture, e.g: tenant isolation, authentication, etc. This blog post only focuses how we can use the [Thanos Receiver](https://thanos.io/v0.14/components/receive) to store time-series from multiple prometheus(es) to acheive multi-tenancy. Also the idea behind this setup is to show how we can make the prometheus on the tenant side nearly stateless yet maintain data resiliency. 
> We will improve this architecture, in the upcoming posts.
We will be building this demo on Thanos v0.14.
# Prerequisites
- [KIND](https://kind.sigs.k8s.io/docs/user/quick-start/) or a managed cluster/minikube 
- `kubectl`
- `helm`
- `jq`(optional)

# Cluster setup

Clone the repo: 
```
git clone https://github.com/dsayan154/thanos-receiver-demo.git
```

## Setup a local [KIND](https://kind.sigs.k8s.io/docs/user/quick-start/) cluster
1. `cd local-cluster/`
2. Create the cluster with calico, ingress and extra-port mappings: `./create-cluster.sh cluster-1 kind-calico-cluster-1.yaml`
3. Deploy the nginx ingress controller: `kubectl apply -f nginx-ingress-controller.yaml`
4. `cd -`

## Install minio as object storage
1. `kubectl create ns minio`
2. `helm repo add bitnami https://charts.bitnami.com/bitnami`
3. `helm upgrade --install --namespace minio my-minio bitnami/minio --set ingress.enabled=true --set accessKey.password=minio --set secretKey.password=minio123 --debug`
4. Add the following line to */etc/hosts*: `127.0.0.1       minio.local`
5. Login to http://minio.local/ with credentials `minio:minio123`.
6. Create a bucket with name **thanos**

## Install Thanos Components
### Create shared components
  ```
  kubectl create ns thanos

  ## Create a file _thanos-s3.yaml_ containing the minio object storage config for tenant-a:   
  cat << EOF > thanos-s3.yaml
  type: S3
  config:
    bucket: "thanos"
    endpoint: "my-minio.minio.svc.cluster.local:9000"
    access_key: "minio"
    secret_key: "minio123"
    insecure: true
  EOF
  
  ## Create secret from the file created above to be used with the thanos components e.g store, receiver 
  kubectl -n thanos create secret generic thanos-objectstorage --from-file=thanos-s3.yaml
  kubectl -n thanos label secrets thanos-objectstorage part-of=thanos

  ## go to manifests directory
  cd manifests/
  ```

### Install Thanos Receive Controller
- Deploy a thanos-receiver-controller to auto-update the hashring configmap when the thanos receiver statefulset scales: 
    ```
    kubectl apply -f thanos-receiver-hashring-configmap-base.yaml
    kubectl apply -f thanos-receive-controller.yaml
    ```

    The deployment above would generate a new configmap `thanos-receive-generated` and keep it updated with a list of endpoints when a statefulset with label: `controller.receive.thanos.io/hashring=hashring-0` and/or `controller.receive.thanos.io/hashring=default`. The thanos receiver pods would load the `thanos-receive-generated` configmaps in them.
    >NOTE: The __default__ and __hashring-0__ hashrings would be responsible for the soft-tenancy and hard-tenancy respectively.

### Install Thanos Receiver
1. Create the thanos-receiver statefulsets and headless services for soft and hard tenants.
   > We are not using persistent volumes just for this demo.
   ```
   kubectl apply -f thanos-receive-default.yaml
   kubectl apply -f thanos-receive-hashring-0.yaml
   ```
   > The receiver pods are configured to store 15d of data and with replication factor of 2
2. Create a service in front of the thanos receive statefulset for the soft tenants.
   ```
   kubectl apply -f thanos-receive-service.yaml
   ```
   > The pods of **thanos-receive-default** statefulset would load-balance the incoming requests to other receiver pods based on the hashring config maintained by the thanos receiver controller.
### Install Thanos Store
1. Create a thanos store statefulsets. 
   ```
   kubectl apply -f thanos-store-shard-0.yaml
   ```
   > We have configured it such that the thanos query only fans out to the store for data older than 2w. Data ealier than 15d are to be provided by the receiver pods. P.S: There is a overlap of 1d between the two time windows is intentional for data-resilency.
### Install Thanos Query
1. Create a thanos query deployment, expose it through service and ingress
   ```
   kubectl apply -f thanos-query.yaml
   ```
   > We configure the thanos query to connect to receiver(s) and store(s) for fanning out queries.

## Install Prometheus(es)
#### Create shared resource
```
kubectl create ns sre 
kubectl create ns tenant-a
kubectl create ns tenant-b
```
## Install Prometheus Operator and Prometheus
We install the [prometheus-operator](https://github.com/prometheus-operator/prometheus-operator) and a default prometheus to monitor the cluster
```
helm upgrade --namespace sre --debug --install cluster-monitor stable/prometheus-operator \
--set prometheus.ingress.enabled=true \
--set prometheus.ingress.hosts[0]="cluster.prometheus.local" \
--set prometheus.prometheusSpec.remoteWrite[0].url="http://thanos-receive.thanos.svc.cluster.local:19291/api/v1/receive" \
--set alertmanager.ingress.enabled=true \
--set alertmanager.ingress.hosts[0]="cluster.alertmanager.local" \
--set grafana.ingress.enabled=true --set grafana.ingress.hosts[0]="grafana.local"
```
## Install Prometheus and ServiceMonitor for tenant-a
In _tenant-a_ namespace:
- Deploy a nginx proxy to forward the requests from prometheus to _thanos-receive_ service in _thanos_ namespace. It also sets the tenant headerof the outgoing request.
```
   kubectl apply -f nginx-proxy-a.yaml
```
- Create a [prometheus](https://coreos.com/operators/prometheus/docs/latest/api.html#prometheus)  and a [servicemonitor](https://coreos.com/operators/prometheus/docs/latest/api.html#servicemonitor)  to monitor itself
```
   kubectl apply -f prometheus-tenant-a.yaml
```

## Install Prometheus and ServiceMonitor for tenant-b
In _tenant-b_ namespace:
- Deploy a nginx proxy to forward the requests from prometheus to _thanos-receive_ service in _thanos_ namespace. It also sets the tenant headerof the outgoing request.
```
   kubectl apply -f nginx-proxy-b.yaml
```
- Create a [prometheus](https://coreos.com/operators/prometheus/docs/latest/api.html#prometheus) and a [servicemonitor](https://coreos.com/operators/prometheus/docs/latest/api.html#servicemonitor) to monitor itself
```
   kubectl apply -f prometheus-tenant-b.yaml
```

### Add some extra localhost aliases
Add the following lines to `/etc/hosts` :
```
127.0.0.1       minio.local
127.0.0.1       query.local
127.0.0.1       cluster.prometheus.local
127.0.0.1       tenant-a.prometheus.local
127.0.0.1       tenant-b.prometheus.local
```
The above would allow you to locally access the [**minio**](http://minio.local), [**thanos query**](http://query.local), [**cluster monitoring prometheus**](http://cluster.prometheus.local), [**tenant-a's prometheus**](http://tenant-a.prometheus.local), [**tenant-b's prometheus**](http://tenant-b.prometheus.local). We are also exposing [Alertmanager](https://prometheus.io/docs/alerting/latest/overview/) and [Grafana](https://prometheus.io/docs/visualization/grafana/), but we don't require those in this demo.

### Test the setup
Access the thanos query from http://query.local/graph and from the UI, execute the query `count (up) by (tenant_id)`. We should see a following output:
<p align=center>
<img src="./images/screenshots/demo_test_result.png"><br>
Query Output
</p>
Otherwise, if we have `jq` installed, you can run the following command:

```
$ curl -s http://query.local/api/v1/query?query="count(up)by("tenant_id")"|jq -r '.data.result[]|"\(.metric) \(.value[1])"'
{"tenant_id":"a"} 1
{"tenant_id":"b"} 1
{"tenant_id":"cluster"} 17
```
Either of the above outputs show that, *cluster*, *a* and *b* prometheus tenants are having 17, 1 and 1 scrape targets up and running. All these data are getting stored in thanos-receiver in real time by prometheus' [remote write queue](https://prometheus.io/docs/practices/remote_write/#remote-write-characteristics). This model creates an oportunity for the tenant side prometheus to be nearly stateless yet maintain data resiliency.
