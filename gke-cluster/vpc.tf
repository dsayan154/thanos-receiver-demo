variable "project_id" {
  description = "project id"
}

variable "region" {
  description = "region"
}

variable "stack_name" {
  description = "stack name"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC
resource "google_compute_network" "vpc" {
  name        = "${var.stack_name}-vpc"
  auto_create_subnetworks = "false"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.stack_name}-subnet"
  region        = "${var.region}"
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.10.0.0/24"
}

output "region" {
  value       = var.region
  description = "region"
}

