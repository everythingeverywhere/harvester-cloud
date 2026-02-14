# CI-first deployment to GCP (GitHub Actions + OIDC Workload Identity Federation)

This is the recommended, best-practice automation path:

- **No JSON keys** stored in GitHub
- GitHub Actions authenticates to GCP via **OIDC → Workload Identity Federation (WIF)**
- Terraform/OpenTofu runs from CI with approvals

> This repo’s GCP Terraform root is: `projects/google-cloud/`.

---

## 1) One-time GCP setup (WIF + Service Account)

### 1.1 Create a deployer service account

```bash
PROJECT_ID=<PROJECT_ID>
SA_NAME=harvester-cloud-ci
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create "${SA_NAME}" \
  --project "${PROJECT_ID}" \
  --display-name "Harvester Cloud CI Deployer"
```

Grant pragmatic roles (see also `docs/gcp/IAM.md`):

```bash
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${SA_EMAIL}" \
  --role "roles/compute.admin"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${SA_EMAIL}" \
  --role "roles/iam.serviceAccountUser"
```

### 1.2 Create a remote state bucket

```bash
REGION=<REGION>
BUCKET_NAME="${PROJECT_ID}-tfstate-harvester-cloud"

gcloud storage buckets create "gs://${BUCKET_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${REGION}" \
  --uniform-bucket-level-access

gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning

gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member "serviceAccount:${SA_EMAIL}" \
  --role "roles/storage.objectAdmin"
```

### 1.3 Create Workload Identity Pool + Provider for GitHub

You’ll create:

- a **Workload Identity Pool** (WIP)
- a **Workload Identity Provider** (OIDC) for GitHub
- a binding that allows your GitHub repo to impersonate the service account

Example:

```bash
PROJECT_ID=<PROJECT_ID>
POOL_ID=github-pool
PROVIDER_ID=github
REPO="everythingeverywhere/harvester-cloud"  # adjust if needed

gcloud iam workload-identity-pools create "${POOL_ID}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

gcloud iam workload-identity-pools providers create-oidc "${PROVIDER_ID}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${POOL_ID}" \
  --display-name="GitHub OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref"

# Allow ONLY this repo to impersonate:
SA_EMAIL="harvester-cloud-ci@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${REPO}"
```

Record these two values for GitHub secrets/vars:

- **Workload Identity Provider** resource name:
  - `projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/<POOL_ID>/providers/<PROVIDER_ID>`
- **Service Account email**: `harvester-cloud-ci@<PROJECT_ID>.iam.gserviceaccount.com`

---

## 2) GitHub repo configuration

### 2.1 Add GitHub Actions secrets / variables

Use **Repository variables** (non-secret) for:

- `GCP_PROJECT_ID`
- `GCP_REGION`
- `TF_STATE_BUCKET`
- `TF_STATE_PREFIX` (e.g. `harvester-cloud/gcp`)

Use **Repository secrets** for anything sensitive:

- `GCP_WIF_PROVIDER` (resource name)
- `GCP_SERVICE_ACCOUNT` (SA email)
- `TFVARS` (optional) — whole `terraform.tfvars` contents if you don’t want them in repo

### 2.2 Environments (approvals)

Create two GitHub Environments:

- `gcp-lab` (no approval) → for **plan**
- `gcp-lab-apply` (requires approval) → for **apply**

The workflow in `.github/workflows/gcp-terraform.yml` uses these.

---

## 3) How the workflow works

- On PRs / pushes: runs **fmt/validate/plan**
- On manual dispatch: can run **apply** (gated by environment approval)
- Uses GCS backend via `terraform init -backend-config=...` (no backend.tf committed)
- Writes a `terraform.tfvars` file from a GitHub secret (optional)

---

## 4) Recommended defaults for low cost + security

- Use `spot_instance = true`
- Use `harvester_cluster_size = "small"`
- Use minimal node count (1 for most labs)
- Set `allowed_cidrs = ["YOUR_PUBLIC_IP/32"]`

---

## 5) Troubleshooting notes

- If nested virtualization errors occur, switch to an Intel-capable machine family per GCP nested virt docs.
- If you see permission errors, start with the pragmatic roles in `docs/gcp/IAM.md`, then tighten later with a custom role.
