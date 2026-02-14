#!/usr/bin/env bash
set -euo pipefail

# bootstrap.sh
# Opinionated bootstrap for harvester-cloud on GCP:
# - enables required APIs
# - creates a GCS bucket for Terraform remote state
# - creates a deployer service account and grants roles
#
# Usage:
#   ./scripts/gcp/bootstrap.sh <PROJECT_ID> <REGION>
#
# Notes:
# - This script is intentionally conservative and idempotent-ish.
# - Review roles before running in stricter environments.

PROJECT_ID="${1:-}"
REGION="${2:-}"

if [[ -z "${PROJECT_ID}" || -z "${REGION}" ]]; then
  echo "Usage: $0 <PROJECT_ID> <REGION>" >&2
  exit 1
fi

SA_NAME="harvester-cloud-deployer"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
BUCKET_NAME="${PROJECT_ID}-tfstate-harvester-cloud"

command -v gcloud >/dev/null 2>&1 || { echo "gcloud is required" >&2; exit 1; }

echo "Using project: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}" >/dev/null

echo "Enabling APIs..."
gcloud services enable \
  compute.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com >/dev/null

echo "Creating state bucket (if missing): gs://${BUCKET_NAME}"
if ! gcloud storage buckets describe "gs://${BUCKET_NAME}" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://${BUCKET_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --uniform-bucket-level-access
fi

gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning >/dev/null || true

echo "Creating service account (if missing): ${SA_EMAIL}"
if ! gcloud iam service-accounts describe "${SA_EMAIL}" >/dev/null 2>&1; then
  gcloud iam service-accounts create "${SA_NAME}" \
    --project "${PROJECT_ID}" \
    --display-name "Harvester Cloud Deployer"
fi

echo "Granting roles to service account at project level..."
# Pragmatic roles for this repo.
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${SA_EMAIL}" \
  --role "roles/compute.admin" >/dev/null

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${SA_EMAIL}" \
  --role "roles/iam.serviceAccountUser" >/dev/null

# Bucket-scoped permission for state object r/w

gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member "serviceAccount:${SA_EMAIL}" \
  --role "roles/storage.objectAdmin" >/dev/null

cat <<EOF

Bootstrap complete.

Next:
  1) Configure Terraform backend:
     Create projects/google-cloud/backend.gcs.tfbackend with:
       bucket = "${BUCKET_NAME}"
       prefix = "harvester-cloud/gcp"

  2) In projects/google-cloud:
       make init BACKEND_CONFIG=backend.gcs.tfbackend
       cp terraform.tfvars.example terraform.tfvars
       # edit terraform.tfvars
       make apply

Recommended (no JSON keys): impersonate the deployer SA:
  export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="${SA_EMAIL}"

EOF
