# Self-hosted GitHub Runner on GCP (recommended for Lab Factory v1)

## Why this is needed

The current Harvester-on-GCP Terraform recipe (`projects/google-cloud/`) performs some orchestration via **SSH provisioners** (`remote-exec` / `file`).

GitHub-hosted runners do **not** have stable, allowlistable egress IPs, which makes it hard to safely restrict `allowed_cidrs` while still permitting the runner to SSH to lab VMs.

A **self-hosted runner** placed inside GCP (same VPC / private network reachability) solves this for v1:

- predictable access path to instances
- you can keep inbound firewalls tight (or even internal-only)
- faster apply/destroy

Longer-term, we should refactor the Terraform recipe to eliminate SSH provisioners.

## v1 approach (manual bootstrap)

1) Create a small GCE VM (Ubuntu 22.04 LTS is fine):
   - machine type: `e2-medium`
   - disk: 20–30GB
   - network: same VPC/subnet as labs (or peered)

2) Install GitHub Actions runner

Follow GitHub’s official docs to register a self-hosted runner to this repo or org.

Recommendation:
- register with labels: `self-hosted`, `gcp`, `lab-factory`
- run it as a system service

3) Lock down permissions

- Runner VM should not have broad GCP perms by default.
- Prefer **OIDC/WIF** even from the runner if possible.
- If you must use a VM service account, keep it least-privilege (compute/network only).

4) Update workflows to use it

In `.github/workflows/gcp-lab-factory.yml`, change:

```yaml
runs-on: ubuntu-latest
```

to something like:

```yaml
runs-on: [self-hosted, gcp, lab-factory]
```

## Future: Terraform-managed runner

We should add a `platform/github-runner-gcp/` stack that:

- creates the VM + firewall
- installs the runner in startup script
- uses Secret Manager for runner registration token

This keeps everything reproducible, but requires careful secret handling.
