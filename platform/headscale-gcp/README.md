# Headscale on GCP (platform stack)

This stack deploys **Headscale** (open-source Tailscale control plane) into the same GCP project you use for Harvester labs.

We use Headscale to avoid depending on conference/customer egress IPs. Sales connects to the tailnet and then demos Harvester via screenshare.

## What this creates

- 1 small Compute Engine VM running:
  - `headscale` (control plane)
  - `caddy` (HTTPS reverse proxy + Let’s Encrypt)
- (Optional) a Cloud DNS `A` record pointing a hostname to the static IP

> v1 design goal: **simple + secure enough**.

---

## Prerequisites

- A GCP project with billing enabled
- A DNS name you control for Headscale, e.g. `headscale.demo.yourdomain.com`
- (Optional) A Cloud DNS managed zone in this project if you want Terraform to create the record

---

## Variables you must set

Create a `terraform.tfvars` (do not commit) with:

- `project_id`
- `region`
- `zone`
- `headscale_hostname` (FQDN)
- `letsencrypt_email`

Example:

```hcl
project_id         = "my-event-project"
region             = "us-central1"
zone               = "us-central1-a"
headscale_hostname = "headscale.demo.example.com"
letsencrypt_email  = "ops@example.com"

# Optional: have Terraform create the A record in Cloud DNS
#create_dns_record  = true
#dns_managed_zone   = "example-com"
```

---

## Deploy

```bash
terraform init -upgrade
terraform apply
```

After apply, Terraform outputs:

- `headscale_url`
- `headscale_ip`

---

## First-time Headscale admin steps (manual)

SSH in (via IAP recommended):

```bash
gcloud compute ssh headscale --zone <ZONE> --tunnel-through-iap
```

Create a user and a reusable preauth key (examples):

```bash
sudo headscale users create sales
sudo headscale preauthkeys create --user sales --reusable --expiration 24h
```

You’ll use that preauth key as a GitHub Secret later to allow a gateway to join the tailnet.

---

## Notes

- This is a platform stack: deploy once, reuse across many labs.
- For stronger security later:
  - move Headscale state to managed Postgres
  - restrict inbound further / add Cloud Armor
  - add monitoring/logging
