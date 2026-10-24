#!/usr/bin/env bash
# source env.sh   (before any terraform command)
# Reads the repo-root .env and exports the two identity variables Terraform needs.
# Everything else lives in envs/*.tfvars, which are safe to commit.
_here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
set -a; . "$_here/../.env"; set +a
export TF_VAR_project="$PROJECT"
export TF_VAR_authorized_cidr="$MY_IP/32"
echo "TF_VAR_project=$TF_VAR_project TF_VAR_authorized_cidr=$TF_VAR_authorized_cidr"
