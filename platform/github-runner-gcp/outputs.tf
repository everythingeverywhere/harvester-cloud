output "runner_name" {
  value       = google_compute_instance.runner.name
  description = "Runner VM name"
}

output "runner_external_ip" {
  value       = google_compute_instance.runner.network_interface[0].access_config[0].nat_ip
  description = "External IP (egress). No inbound ports are opened by this stack by default."
}

output "runner_service_account" {
  value       = google_service_account.runner.email
  description = "Runner VM service account"
}
