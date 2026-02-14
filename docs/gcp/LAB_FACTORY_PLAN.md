# Harvester Lab Factory on GCP (CI-first) — Plan + Progress

## Goal
Provide **self-serve, ephemeral Harvester labs** for sales demos.

- Sales person requests a lab
- Lab is reachable securely (no conference CIDR dependency)
- Default TTL **8 hours** with ability to extend
- Labs auto-destroy to control cost

## Non-goals (for v1)
- Customer direct access (no client install). Sales screenshares.
- Production hardening / HA for Headscale

## High-level architecture (v1)

**Single GCP project** contains:

1) **Headscale control plane** (small VM) — always-on
2) **Harvester labs** (GCE instances) — ephemeral, many

**Access model:** sales laptops run Tailscale client and connect to Headscale-managed tailnet.

> We will aim to avoid exposing Harvester UI publicly; access is over tailnet.

## Phases

### Phase 1 (now): Headscale + CI lab workflows

Deliverables:

- Terraform stack to deploy Headscale on GCP
- GitHub Actions workflows:
  - request-lab (apply)
  - extend-lab (update TTL metadata)
  - destroy-lab
  - reaper (scheduled cleanup)
- QA/QC:
  - fmt/validate/tflint/checkov
  - post-apply smoke test (basic liveness)

### Phase 2: Rancher control plane

- Deploy Rancher (recommended: GKE Autopilot)
- Auto-import each Harvester lab using existing rancher2 provider inputs

### Phase 3: Internal Web UI

- Simple internal portal to list/create/extend/destroy labs
- Portal triggers GitHub workflows (fast path) or calls a small API service

## Implementation choices (v1)

### Lab identity & state isolation
- Each lab has a `lab_id` (e.g. `cust-acme-20260214-2315`)
- Terraform remote state prefix per lab:
  - `harvester-cloud/gcp/labs/${lab_id}`

### TTL & cleanup
- Each lab is labeled/tagged with:
  - `lab_id`
  - `owner` (sales)
  - `expires_at` (RFC3339 or unix timestamp)
- Reaper workflow runs hourly and destroys expired labs.

### Security guardrails
- No `0.0.0.0/0` ingress by default.
- Keep SSH/UI access over tailnet.
- CI uses GCP OIDC/WIF; no JSON keys.

## Progress log

### 2026-02-14
- Added CI-first Terraform workflow scaffolding for GCP.
- Added docs: CI (OIDC/WIF), IAM guidance.
- Added `allowed_cidrs` variable wired into firewall.
- Rewrote `docs/gcp/README.md` to be CI-first and step-by-step.

## Next tasks (ordered)

1) Fix/verify GitHub Actions workflow correctness (YAML, steps, versions).
2) Add platform stack for Headscale (Terraform):
   - VM + firewall + static IP + DNS + TLS (Let’s Encrypt)
   - outputs: URL, admin key/secrets handling plan
3) Add lab workflows:
   - request-lab with lab_id + backend prefix
   - destroy-lab
   - extend-lab (metadata)
   - reaper
4) Add CI checks:
   - tflint
   - checkov
   - policy: forbid open `allowed_cidrs` unless explicitly overridden

