# harvester-cloud

Terraform-based recipes and modules to deploy **Harvester** on public cloud infrastructure (instead of bare metal) for:

- labs
- testing
- sales / SE PoCs

⚠️ **Not intended for production use.**

---

## Quick start (GCP)

Two ways to run Harvester on GCP:

1) **Local CLI (fastest to try once):**
   - `projects/google-cloud/README.md`

2) **CI-first (best practice for repeatability):**
   - `docs/gcp/README.md`
   - `docs/gcp/CI.md` (OIDC → Workload Identity Federation)
   - `docs/gcp/IAM.md`

### Lab Factory (sales PoC automation)

We’re actively building a “Lab Factory” pattern for **self-serve, repeatable, ephemeral** Harvester labs on GCP:

- Plan + progress: `docs/gcp/LAB_FACTORY_PLAN.md`
- Operator runbook: `docs/gcp/LAB_FACTORY_RUNBOOK.md`
- Workflow entrypoint (create/extend/destroy): `.github/workflows/gcp-lab-factory.yml`

> Important: the current `projects/google-cloud` recipe uses SSH provisioners. For safe, fully automated CI, v1 should use a **self-hosted GitHub runner in GCP** or we should refactor the recipe to avoid SSH provisioners.

---

## Repository structure

```text
.
├── modules/     # reusable building blocks per provider and Harvester ops
├── projects/    # opinionated “recipes” composed from modules
├── docs/        # how-to guides and design notes
├── platform/    # optional always-on platform components (e.g., Headscale)
└── scripts/     # helper scripts (bootstrap, metadata, etc.)
```

- `modules/` contains provider modules (GCP/Azure/DO) and Harvester operations modules.
- `projects/` contains end-to-end recipes like “Harvester on GCP (1 or 3 nodes)”.

---

## Key docs

- Terraform CLI prep: `docs/TERRAFORM.md`
- OpenTofu CLI prep: `docs/OPENTOFU.md`
- Estimated costs: `docs/INFRASTRUCTURE_ESTIMATED_COSTS.md`
- Harvester deployment process: `docs/HARVESTER_DEPLOYMENT_PROCESS.md`

GCP specific:
- CI-first GCP deployment: `docs/gcp/README.md`
- CI wiring (OIDC/WIF): `docs/gcp/CI.md`
- IAM notes: `docs/gcp/IAM.md`

---

## Projects (recipes)

- Google Cloud: `projects/google-cloud/README.md`
- Azure: `projects/azure/README.md`
- DigitalOcean: `projects/digitalocean/README.md`

Harvester Operations:
- Image creation: `projects/harvester-ops/image-creation/README.md`
- Network creation: `projects/harvester-ops/network-creation/README.md`
- VM pool creation: `projects/harvester-ops/vm-pool-creation/README.md`
