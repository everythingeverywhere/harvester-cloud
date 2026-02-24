# GitHub Actions Self-hosted Runner on GCP (Lab Factory v1)

This stack provisions a small VM in **the same GCP project** as the Harvester labs and installs a **self-hosted GitHub Actions runner**.

Why: the current `projects/google-cloud` lab recipe uses SSH provisioners. GitHub-hosted runners do not have stable egress IPs to allowlist safely, so v1 automation is best run from a runner inside GCP.

## Security model / best practices

- Runner VM has **no inbound firewall rules** by default (no public services exposed).
- Runner uses **OIDC/WIF** for GCP access (same as other workflows). The VM itself only needs enough permissions to fetch the GitHub runner registration token from Secret Manager.
- The GitHub runner registration token is stored in **Secret Manager** and read at boot.
- Prefer a **repo-level** runner for v1 simplicity.

## Prereqs

- A GCP project (same project you will use for labs)
- Terraform or OpenTofu
- A GitHub runner registration token stored as a Secret Manager secret (see below)

## Step 1 — Create the GitHub runner token secret (manual)

Generate a runner registration token in GitHub:

- Repo → Settings → Actions → Runners → New self-hosted runner

Then create a Secret Manager secret:

```bash
gcloud secrets create github_runner_token --replication-policy=automatic
printf '%s' "<TOKEN>" | gcloud secrets versions add github_runner_token --data-file=-
```

Notes:
- These tokens expire; rotate by adding a new version.

## Step 2 — Deploy the runner VM

Copy example tfvars:

```bash
cd platform/github-runner-gcp
cp terraform.tfvars.example terraform.tfvars
```

Edit required values:
- `project_id`
- `region`
- `zone`
- `github_repo` (e.g. `everythingeverywhere/harvester-cloud`)

Apply:

```bash
terraform init -upgrade
terraform apply
```

## Step 3 — Switch Lab Factory workflows to use the self-hosted runner

In:
- `.github/workflows/gcp-lab-factory.yml`
- `.github/workflows/gcp-lab-reaper.yml`

Set:

```yaml
runs-on: [self-hosted, gcp, lab-factory]
```

(These lines are already present as comments; uncomment once the runner is online.)

## Troubleshooting

- Check runner status: GitHub → Repo → Settings → Actions → Runners
- Check VM logs in GCP:
  - serial console output
  - `/var/log/syslog` and `/var/log/cloud-init-output.log`

## TODO (future)

- Harden further: private VM + Cloud NAT, OS Login, shielded VM policies.
- Replace token-based registration with a GitHub App flow (more automation, less manual rotation).
