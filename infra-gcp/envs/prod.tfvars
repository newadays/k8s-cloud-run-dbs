# project and authorized_cidr are not in this file: they come from TF_VAR_project / TF_VAR_authorized_cidr. Run: source env.sh
region           = "us-central1"
env              = "prod"
db_tier          = "db-custom-2-7680"
create_cloud_run = false
create_gke       = true
github_repository = "newadays/k8s-cloud-run-dbs"   # Lab 5.1: the only repo allowed to assume ci-pipeline
