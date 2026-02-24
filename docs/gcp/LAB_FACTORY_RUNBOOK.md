# Harvester Lab Factory on GCP — Runbook (CI-first)

This runbook describes how to operate **self-serve, repeatable Harvester labs** on Google Cloud for sales PoCs.

> Repo goal: a sales engineer (or enablement) can create/destroy a lab via GitHub Actions with guardrails, predictable cost, and strong defaults.

## What exists today

- Core Harvester-on-GCP Terraform recipe: `projects/google-cloud/`
- GCP CI-first workflow (plan/apply/destroy for a single environment): `.github/workflows/gcp-terraform.yml`
- Lab Factory plan/progress: `docs/gcp/LAB_FACTORY_PLAN.md`
- (Optional platform stack) Headscale on GCP: `platform/headscale-gcp/`

## v1 Operating Model (recommended)

### Identity
Each lab gets a **lab_id** (string):

- Example: `acme-demo-20260224-1530`
- Used for:
  - resource name prefix
  - terraform remote state prefix isolation

### Remote state isolation
State is isolated per lab by using a per-lab backend prefix:

- `harvester-cloud/gcp/labs/${lab_id}`

### TTL / cleanup
v1 uses a lightweight metadata file stored in the TF state bucket:

- `gs://$TF_STATE_BUCKET/harvester-cloud/gcp/labs/${lab_id}/meta.json`

Contents include:

- `lab_id`
- `owner`
- `expires_at` (RFC3339)
- `created_at` (RFC3339)
- `notes`

A future scheduled “reaper” workflow will:

1) list `meta.json` objects
2) destroy labs whose `expires_at` is in the past

## Workflows (v1)

### 1) Request / Create Lab
Input:

- `lab_id`
- `owner`
- `ttl_hours` (default 8)
- `project_id`, `region`
- `harvester_node_count` (1 or 3)
- `storage_profile` (none|standard|heavy)

Action:

- writes/updates `meta.json`
- runs `terraform apply` with backend prefix `.../labs/${lab_id}`

### 2) Extend Lab
Input:

- `lab_id`
- `ttl_hours` to extend

Action:

- updates `meta.json` only

### 3) Destroy Lab
Input:

- `lab_id`

Action:

- runs `terraform destroy` using the same backend prefix
- (optional) deletes `meta.json`

## Notes on access

Today’s `projects/google-cloud` recipe uses SSH provisioners for some steps. That makes running it from **public GitHub runners** tricky because you either need:

- an allowlistable source IP (not true for GitHub hosted runners), or
- a self-hosted runner in GCP/VPC, or
- a redesign to remove SSH provisioners (move all bootstrap to instance startup scripts).

**v1 recommendation**: use a **self-hosted runner** inside GCP for apply/destroy operations.

## Next engineering milestones

- Add `gcp-lab-factory.yml` workflow with per-lab state prefix + metadata.
- Add a `platform/github-runner-gcp/` stack to run a hardened self-hosted runner.
- Add scheduled reaper workflow.
- Add guardrails (tflint/checkov + policy checks) to prevent wide-open ingress.
