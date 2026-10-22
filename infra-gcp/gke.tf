# The Kubernetes option for tier 1 (Modules 3 and 4): private regional GKE Standard cluster.

resource "google_container_cluster" "two_tier" {
  count    = var.create_gke ? 1 : 0
  name     = "two-tier"
  location = var.region # regional: control plane and nodes in 3 zones

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.app.id

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = local.is_prod

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  datapath_provider = "ADVANCED_DATAPATH" # Dataplane V2: eBPF, NetworkPolicy enforced without Calico

  private_cluster_config {
    enable_private_nodes    = true # nodes have no public IP
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.authorized_cidr
      display_name = "operator"
    }
  }

  workload_identity_config {
    workload_pool = "${var.project}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus { enabled = true }
  }

  resource_labels = local.labels
}

resource "google_container_node_pool" "general" {
  count    = var.create_gke ? 1 : 0
  name     = "general"
  cluster  = google_container_cluster.two_tier[0].id
  location = var.region

  node_count = 1 # per zone, so 3 nodes total

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = "e2-medium"
    disk_size_gb    = 50
    disk_type       = "pd-balanced"
    service_account = google_service_account.nodes.email # not the default compute SA
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels          = local.labels

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    workload_metadata_config {
      mode = "GKE_METADATA" # pods get their own identity; node SA token is not reachable
    }
  }
}
