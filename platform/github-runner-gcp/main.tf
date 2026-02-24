locals {
  startup = templatefile("${path.module}/startup.sh.tpl", {
    github_repo              = var.github_repo
    github_token_secret_name = var.github_token_secret_name
    runner_labels            = var.runner_labels
    runner_name              = var.name
  })
}

resource "google_service_account" "runner" {
  account_id   = replace(var.name, "_", "-")
  display_name = "Lab Factory GitHub runner VM SA"
}

# Minimal perms: read the runner token secret.
resource "google_project_iam_member" "runner_secret_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

# Optional but useful: allow writing logs/metrics.
resource "google_project_iam_member" "runner_logs" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

resource "google_project_iam_member" "runner_metrics" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

resource "google_compute_instance" "runner" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone

  labels = merge(var.labels, {
    "component" = "github-runner"
  })

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = 30
      type  = "pd-balanced"
    }
  }

  network_interface {
    # default network; for v1 simplicity.
    network = "default"

    # Public egress (needed to reach github.com) but we do not open inbound firewall ports.
    access_config {}
  }

  service_account {
    email  = google_service_account.runner.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata_startup_script = local.startup

  # Harden a bit (still room for improvement):
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}
