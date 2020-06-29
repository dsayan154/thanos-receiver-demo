variable "gke_username" {
  default = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "created_by" {
  default     = ""
  description = "created by"
}

variable "gke_node_count" {
  default     = 3
  description = "number of nodes of the gke cluster"
}

# GKE cluster
data "google_container_engine_versions" "zone" {
  location       = var.region
}

resource "google_container_cluster" "cluster" {
  name                = "${var.stack_name}-gke"
  location            = var.region
  min_master_version  = data.google_container_engine_versions.zone.latest_master_version
  
  remove_default_node_pool  = true
  initial_node_count        = 1
  
  network     = google_compute_network.vpc.name
  subnetwork  = google_compute_subnetwork.subnet.name
  
  master_auth {
    username  = var.gke_username
    password  = var.gke_password
    
    client_certificate_config {
      issue_client_certificate  = false
    }
  }
  resource_labels = {
    env         = var.stack_name
    created_by  = var.created_by
    #provisioner = var.provisioner
  }
}

# Separately Managed Node Pool
resource "google_container_node_pool" "nodes" {
  name       = "${google_container_cluster.cluster.name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.cluster.name
  node_count = var.gke_node_count

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env         = var.stack_name
      created_by  = var.created_by
      #provisioner = var.provisioner
    }

    preemptible  = true
    machine_type = "n1-standard-1"
    tags         = ["gke-node", "${var.stack_name}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
output "kubernetes_cluster_name" {
  value       = google_container_cluster.cluster.name
  description = "GKE Cluster Name"
}
