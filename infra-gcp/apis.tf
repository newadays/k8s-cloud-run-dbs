# Enable the APIs the rest of the config needs. disable_on_destroy = false so a
# terraform destroy does not turn off APIs other things in the project may use.
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "vpcaccess.googleapis.com",
    "iam.googleapis.com",
    "binaryauthorization.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}
