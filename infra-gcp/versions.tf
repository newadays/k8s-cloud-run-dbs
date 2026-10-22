terraform {
  required_version = ">= 1.6"

  # Remote state: create the bucket once by hand, with versioning on.
  #   gcloud storage buckets create gs://PROJECT-tfstate --location us-central1 --uniform-bucket-level-access
  #   gcloud storage buckets update gs://PROJECT-tfstate --versioning
  # Then: terraform init -backend-config="bucket=PROJECT-tfstate"
  backend "gcs" {
    prefix = "two-tier"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
