# Lab 5.1: keyless auth from GitHub Actions to Google Cloud (Workload Identity Federation).
#
# GitHub signs an OIDC token for every workflow run. Google's STS exchanges that token for a short-lived
# credential as ci-pipeline, but only when the token's `repository` claim matches var.github_repository.
# No service account key exists anywhere. Revoke access by deleting the binding, not by rotating a secret.
#
# Pool and provider ids are soft-deleted for 30 days and cannot be reused in that window, so pick them once.

data "google_project" "this" {
  project_id = var.project
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  description               = "Identities for workflows in ${var.github_repository}"
  depends_on                = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Which token claims become attributes you can bind on. `google.subject` is mandatory.
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  # Reject every token that is not from this repository before any IAM binding is consulted.
  attribute_condition = "assertion.repository == \"${var.github_repository}\""
}

# Any workflow run in the repository may impersonate ci-pipeline. Narrow further with
# attribute.ref == "refs/heads/main" if only main should be allowed to push images.
resource "google_service_account_iam_member" "ci_workload_identity" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

# These two go into GitHub repository variables (WIF_PROVIDER, CI_SERVICE_ACCOUNT). See README.
output "wif_provider" {
  description = "workload_identity_provider for google-github-actions/auth"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "ci_service_account" {
  value = google_service_account.ci.email
}
