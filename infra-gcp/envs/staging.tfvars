# project and authorized_cidr are not in this file: they come from TF_VAR_project / TF_VAR_authorized_cidr. Run: source env.sh
region           = "us-central1"
env              = "staging"
db_tier          = "db-f1-micro"
create_cloud_run = true
create_gke       = true
# image = "us-central1-docker.pkg.dev/PROJECT/apps/api@sha256:DIGEST"   # set after Lab 2.3
github_repository = "newadays/k8s-cloud-run-dbs"   # Lab 5.1: the only repo allowed to assume ci-pipeline
