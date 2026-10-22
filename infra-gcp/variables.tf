variable "project" {
  description = "GCP project id"
  type        = string
}

variable "region" {
  description = "Region for the VPC subnet, Cloud SQL, GKE, Cloud Run, Artifact Registry"
  type        = string
  default     = "us-central1"
}

variable "env" {
  description = "staging or prod; drives HA, deletion protection, and sizing"
  type        = string
  validation {
    condition     = contains(["staging", "prod"], var.env)
    error_message = "env must be staging or prod"
  }
}

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-f1-micro"
}

variable "image" {
  description = "API image for Cloud Run, by digest: us-central1-docker.pkg.dev/PROJECT/apps/api@sha256:..."
  type        = string
  default     = ""
}

variable "create_gke" {
  description = "Create the GKE cluster (Module 3 and 4). Off by default so Lab 1b.2 stays cheap."
  type        = bool
  default     = false
}

variable "create_cloud_run" {
  description = "Create the Cloud Run service (the App Runner equivalent from the AWS template)."
  type        = bool
  default     = true
}

variable "authorized_cidr" {
  description = "Your IP in CIDR form, allowed to reach the GKE control plane"
  type        = string
}

locals {
  is_prod = var.env == "prod"
  labels  = { app = "two-tier", env = var.env, managed_by = "terraform" }
}
