# Deploy Harvester Cloud to Google Cloud (GCP) — CI-first

You already have a working GCP Terraform recipe in this repo at `projects/google-cloud/`.

This document explains the **recommended, CI-first** way to run it using **GitHub Actions + keyless GCP auth (OIDC → Workload Identity Federation)**, with a focus on:

- **best practices** (remote state, approvals, repeatability)
- **low cost** (Spot VMs, small profiles, easy destroy)
- **security** (no JSON keys, restricted ingress via `allowed_cidrs`)

If you want the full CI wiring steps (Workload Identity Pool/Provider commands, etc.), this guide pairs with:

- **CI setup details:** `docs/gcp/CI.md`
- **IAM guidance (roles + impersonation):** `docs/gcp/IAM.md`

> Scope: **GCP only**. This repo is for labs/PoCs and testing, not production.

---

## What gets deployed

When you apply the Terraform in `projects/google-cloud/`, it creates Google Compute Engine resources (VMs + disks + networking) that host Harvester with **nested virtualization enabled**.

In practice, you will:

1) prepare GCP (APIs, state bucket, CI deployer identity)
2) configure variables (cluster size, region, costs, ingress restrictions)
3) run **plan** automatically on PRs
4) run **apply/destroy** manually from GitHub Actions with approvals

---

## Step 1 — Pick the “lab defaults” (cost + security)

Before you run anything, decide the defaults you want CI to enforce. These are the settings that matter most for cost and exposure.

For a cheap and safe lab environment:

- `spot_instance = true` (default)
- `harvester_cluster_size = "small"`
- `harvester_node_count = 1` (use 3 only when you need HA-like behavior)
- `allowed_cidrs = ["YOUR_PUBLIC_IP/32"]` (do not leave it open unless you’re intentionally demoing)

`allowed_cidrs` is wired into the GCP firewall rule in the Google module.

---

## Step 2 — One-time GCP setup (remote state + CI identity)

CI needs two foundational things:

1) a **GCS bucket** for Terraform remote state
2) a **service account** that GitHub Actions can impersonate via **Workload Identity Federation**

Rather than duplicating those instructions here, use:

- `docs/gcp/CI.md` (this is the step-by-step)

At the end of that setup you will have:

- `TF_STATE_BUCKET` (GCS bucket name)
- `TF_STATE_PREFIX` (recommended: `harvester-cloud/gcp`)
- `GCP_WIF_PROVIDER` (Workload Identity Provider resource name)
- `GCP_SERVICE_ACCOUNT` (service account email)

---

## Step 3 — Add GitHub repo Variables/Secrets and approvals

This is the point where “CI-first” becomes real.

In your GitHub repo settings:

**Repository Variables (non-secret)**

- `TF_STATE_BUCKET`
- `TF_STATE_PREFIX`

**Repository Secrets (sensitive)**

- `GCP_WIF_PROVIDER`
- `GCP_SERVICE_ACCOUNT`
- optional: `TFVARS` (the full contents of `terraform.tfvars`)

Then create GitHub Environments:

- `gcp-lab` (used for plan)
- `gcp-lab-apply` (used for apply/destroy; configure **required reviewers**)

This gives you a clean approval gate before anything is created or destroyed.

---

## Step 4 — Decide where `terraform.tfvars` lives

You have two good options:

### Option A (recommended for CI-first): store tfvars in a GitHub Secret

Put the full `terraform.tfvars` contents into the secret named `TFVARS`.

This keeps environment configuration out of the repo while still being automated.

### Option B: keep a non-secret `terraform.tfvars` in the repo

This is fine only if you keep it free of secrets (no tokens/passwords) and you accept that anyone with repo read access can see it.

> This repo already `.gitignore`s `terraform.tfvars` by default, which nudges you toward Option A.

---

## Step 5 — Run the pipeline

The workflow file is:

- `.github/workflows/gcp-terraform.yml`

### What happens automatically

- On PRs and pushes to `main`, CI runs:
  - `terraform fmt -check`
  - `terraform validate`
  - `terraform plan`

This is your “always-on safety net”: you see what would change before you approve it.

### What you run manually (with approval)

From GitHub Actions → **Run workflow**:

- `apply` to create/update infrastructure
- `destroy` to tear it down and stop costs

Because apply/destroy uses the `gcp-lab-apply` environment, it can be protected by required reviewers.

---

## Step 6 — Access and verify

After a successful apply, use the outputs/files produced by the Terraform recipe in `projects/google-cloud/`.

Typical checks:

- export kubeconfig and confirm nodes:
  - `kubectl get nodes`
- open the Harvester UI using the output URL/credentials
- create one small VM and confirm networking and storage

---

## Step 7 — Cleanup (cost control)

For labs, the best cost optimization is simple: destroy when you’re done.

Run the GitHub Actions workflow with input `destroy`.

Remote state remains in GCS so the next apply is clean and repeatable.

---

## Where to look in this repo

- GCP Terraform root: `projects/google-cloud/`
- GCP module: `modules/google-cloud/`
- CI setup (OIDC/WIF): `docs/gcp/CI.md`
- IAM notes: `docs/gcp/IAM.md`
- General deployment flow: `docs/HARVESTER_DEPLOYMENT_PROCESS.md`
- Cost estimates: `docs/INFRASTRUCTURE_ESTIMATED_COSTS.md`

---

## Optional (local admin bootstrap)

If you want a local helper to bootstrap a project quickly (enable APIs, create state bucket, create a deployer SA), there is:

- `scripts/gcp/bootstrap.sh`

This is useful for initial setup or debugging, but the intended steady-state is **CI-first**.
