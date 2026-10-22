# Tier 2: Cloud SQL for PostgreSQL, private IP only, password generated here and
# stored in Secret Manager so it never passes through a variable or a tfvars file.
# (It is still in Terraform state; see Module 1b Part D on protecting state.)

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "db_password" {
  secret_id  = "db-password"
  labels     = local.labels
  depends_on = [google_project_service.apis]
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}

#trivy:ignore:GCP-0021 slow-query logging is wanted on this app; it logs statements over 1s, not all statements
resource "google_sql_database_instance" "db" {
  #checkov:skip=CKV_GCP_6: ssl_mode=ENCRYPTED_ONLY is set; the check looks for the deprecated require_ssl attribute
  #checkov:skip=CKV_GCP_79: Postgres 16 is pinned on purpose; major upgrades are a planned change, not a lint fix
  #checkov:skip=CKV_GCP_110: pgAudit is an enterprise control; out of scope for the lab database
  #checkov:skip=CKV_GCP_57: slow-query logging (log_min_duration_statement) is wanted on this app
  #checkov:skip=CKV_GCP_111: log_statement=all would log every query and its data; the slow-query log is enough
  #checkov:skip=CKV2_GCP_13: log_duration logs timing for every statement; noisy, covered by log_min_duration_statement
  name                = "two-tier-db"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = local.is_prod
  depends_on          = [google_service_networking_connection.psa]

  settings {
    tier              = var.db_tier
    edition           = "ENTERPRISE" # db-f1-micro only exists in this edition
    availability_type = local.is_prod ? "REGIONAL" : "ZONAL"
    disk_autoresize   = true
    user_labels       = local.labels

    ip_configuration {
      ipv4_enabled    = false # no public IP, ever
      private_network = google_compute_network.vpc.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      transaction_log_retention_days = local.is_prod ? 7 : 3 # must be <= retained_backups
      backup_retention_settings { retained_backups = local.is_prod ? 14 : 3 }
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }
    # CIS logging flags (Checkov CKV_GCP_51/53/54/108/109, Trivy GCP-0014). Free; restart on first apply.
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }
    database_flags {
      name  = "log_hostname"
      value = "on"
    }
    database_flags {
      name  = "log_min_error_statement"
      value = "error"
    }
    database_flags {
      name  = "log_temp_files"
      value = "0"
    }

    maintenance_window {
      day  = 7
      hour = 4
    }
  }
}

resource "google_sql_database" "app" {
  name     = "app"
  instance = google_sql_database_instance.db.name
}

resource "google_sql_user" "app" {
  name     = "app"
  instance = google_sql_database_instance.db.name
  password = random_password.db.result
}
