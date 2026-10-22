# Custom VPC, one subnet with secondary ranges for GKE pods and services,
# and a Private Services Access range so Cloud SQL gets a private IP only.

resource "google_compute_network" "vpc" {
  name                    = "two-tier-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "app" {
  name                     = "app-subnet"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.10.0.0/24"
  private_ip_google_access = true # reach Google APIs from private nodes without public IPs

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/16"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.30.0.0/20"
  }

  log_config {
    aggregation_interval = "INTERVAL_5_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Cloud NAT so private nodes and the serverless connector can pull images and reach the internet outbound.
resource "google_compute_router" "router" {
  name    = "two-tier-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "two-tier-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Private Services Access: the peering range Cloud SQL's private IP comes from.
resource "google_compute_global_address" "psa" {
  name          = "psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]
}

# Firewall: nothing inbound from the internet to nodes. GKE and the load balancer
# add their own rules; this is the explicit deny-by-default posture for anything else.
resource "google_compute_firewall" "deny_ingress" {
  name      = "two-tier-deny-all-ingress"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 65000
  deny { protocol = "all" }
  source_ranges = ["0.0.0.0/0"]
}

# Allow Google's load balancer and health-check ranges to reach the API port.
resource "google_compute_firewall" "allow_lb_health" {
  name      = "two-tier-allow-lb-health"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 1000
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}
