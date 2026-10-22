# Adopt the resources created by hand in Lab 1.1 so Terraform manages them
# instead of failing with "already exists". Delete this file after the first
# successful apply; the state then carries the mappings.
locals { p = var.project }

import {
  to = google_compute_network.vpc
  id = "projects/${local.p}/global/networks/two-tier-vpc"
}
import {
  to = google_compute_subnetwork.app
  id = "projects/${local.p}/regions/${var.region}/subnetworks/app-subnet"
}
import {
  to = google_compute_global_address.psa
  id = "projects/${local.p}/global/addresses/google-managed-services-two-tier-vpc"
}
import {
  to = google_service_networking_connection.psa
  id = "projects/${local.p}/global/networks/two-tier-vpc:servicenetworking.googleapis.com"
}
import {
  to = google_secret_manager_secret.db_password
  id = "projects/${local.p}/secrets/db-password"
}
import {
  to = google_sql_database_instance.db
  id = "projects/${local.p}/instances/two-tier-db"
}
import {
  to = google_sql_database.app
  id = "projects/${local.p}/instances/two-tier-db/databases/app"
}
import {
  to = google_sql_user.app
  id = "${local.p}/two-tier-db/app"
}
