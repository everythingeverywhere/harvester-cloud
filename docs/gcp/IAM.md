# GCP IAM: least-privilege(ish) deployer for harvester-cloud

Terraform needs broad permissions across Compute resources (instances, disks, networks, firewall rules, addresses). The simplest path is to grant a service account a small set of **project-level roles**.

This doc provides:

- a pragmatic minimal set of roles that typically works
- notes for tightening further (custom role)

> Goal: keep this **secure enough for labs**, without turning IAM into a multi-day project.

---

## Recommended: dedicated deployer Service Account

Create a service account in the target project (or a separate “platform” project if you standardize).

```bash
PROJECT_ID=<PROJECT_ID>
SA_NAME=harvester-cloud-deployer
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create "${SA_NAME}" \
  --project "${PROJECT_ID}" \
  --display-name "Harvester Cloud Deployer"
```

### Roles to grant (project-level)

These are the common roles needed for this repo’s GCP resources:

- `roles/compute.admin`
  - create instances, disks, networks, subnets, firewall rules
- `roles/iam.serviceAccountUser`
  - needed if Terraform attaches/uses service accounts on VMs, or if you run via impersonation workflows
- `roles/storage.admin` (ONLY if this SA also manages the **state bucket**)
  - if you prefer separation of duties: manage bucket out-of-band and grant `roles/storage.objectAdmin` on the bucket instead

Grant example:

```bash
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${SA_EMAIL}" \
  --role "roles/compute.admin"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${SA_EMAIL}" \
  --role "roles/iam.serviceAccountUser"

# If the deployer SA creates/manages the state bucket:
#gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
#  --member "serviceAccount:${SA_EMAIL}" \
#  --role "roles/storage.admin"
```

### If using a pre-created state bucket (preferred hardening)

If you create the GCS bucket separately, grant bucket-scoped access:

- `roles/storage.objectAdmin` (read/write objects)
- optionally `roles/storage.legacyBucketReader` (list bucket)

Example (bucket-level IAM):

```bash
BUCKET_NAME=<BUCKET_NAME>

gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member "serviceAccount:${SA_EMAIL}" \
  --role "roles/storage.objectAdmin"
```

---

## Auth options

### Best: impersonation (no JSON keys)

Use your human user account to impersonate the deployer SA:

```bash
gcloud auth login

gcloud config set project <PROJECT_ID>

gcloud auth application-default login

export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="${SA_EMAIL}"
```

You must also allow your user to impersonate the SA:

```bash
MY_USER="user:you@example.com"

gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --member "${MY_USER}" \
  --role "roles/iam.serviceAccountTokenCreator"
```

### Alternate: JSON key (avoid if possible)

If you must use keys, treat them like passwords; store securely; rotate.

---

## Tightening further (CTO/Architect path)

If we want true least-privilege:

1) Run `terraform plan` with broad roles
2) Inspect audit logs / permission errors
3) Build a **custom role** with only the required `compute.*` permissions
4) Use bucket-level IAM for state

This takes time but pays off if you’ll run it in CI/CD.
