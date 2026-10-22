# The serverless option for tier 1 (Lab 1.1), equivalent to App Runner in the AWS template.
# Same image as GKE; reaches Cloud SQL over private IP through a Serverless VPC connector.

resource "google_vpc_access_connector" "connector" {
  count         = var.create_cloud_run ? 1 : 0
  name          = "two-tier-connector"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.8.0.0/28"
  min_instances = 2
  max_instances = 3
  depends_on    = [google_project_service.apis]
}

resource "google_cloud_run_v2_service" "api" {
  count               = var.create_cloud_run && var.image != "" ? 1 : 0
  name                = "api"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL" # public HTTPS; use INTERNAL_LOAD_BALANCER behind a LB with Cloud Armor in prod
  deletion_protection = false
  labels              = local.labels

  template {
    service_account = google_service_account.api.email
    scaling {
      min_instance_count = local.is_prod ? 1 : 0
      max_instance_count = 10
    }
    vpc_access {
      connector = google_vpc_access_connector.connector[0].id
      egress    = "PRIVATE_RANGES_ONLY"
    }
    containers {
      image = var.image
      ports { container_port = 8080 }
      resources {
        limits = { cpu = "1", memory = "512Mi" }
      }
      env {
        name  = "DB_HOST"
        value = google_sql_database_instance.db.private_ip_address
      }
      env {
        name  = "DB_USER"
        value = "app"
      }
      env {
        name  = "DB_NAME"
        value = "app"
      }
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }
      startup_probe {
        http_get { path = "/healthz/ready" }
        period_seconds    = 5
        failure_threshold = 6
      }
      liveness_probe {
        http_get { path = "/healthz/live" }
      }
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.api_db_password]
}

# Public, unauthenticated invoke for the lab. Remove this binding to require IAM auth.
resource "google_cloud_run_v2_service_iam_member" "public" {
  count    = var.create_cloud_run && var.image != "" ? 1 : 0
  name     = google_cloud_run_v2_service.api[0].name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
