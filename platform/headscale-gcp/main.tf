terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.17"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_address" "headscale" {
  name   = "headscale-ip"
  region = var.region
}

# Optional: create an A record if you manage DNS in Cloud DNS.
resource "google_dns_record_set" "headscale_a" {
  count        = var.create_dns_record ? 1 : 0
  managed_zone = var.dns_managed_zone
  name         = "${var.headscale_hostname}."
  type         = "A"
  ttl          = 60
  rrdatas      = [google_compute_address.headscale.address]
}

resource "google_compute_firewall" "headscale" {
  name    = "headscale-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  # Headscale needs to be reachable from the internet for clients.
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["headscale"]
}

# Break-glass admin access via IAP SSH.
resource "google_compute_firewall" "iap_ssh" {
  name    = "headscale-iap-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP TCP forwarding range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["headscale"]
}

resource "google_compute_instance" "headscale" {
  name         = "headscale"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["headscale"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.headscale.address
    }
  }

  metadata = {
    startup-script = templatefile("${path.module}/startup.sh.tpl", {
      headscale_hostname = var.headscale_hostname
      letsencrypt_email  = var.letsencrypt_email
      headscale_version  = var.headscale_version
    })
  }
}
