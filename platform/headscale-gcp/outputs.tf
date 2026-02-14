output "headscale_ip" {
  value       = google_compute_address.headscale.address
  description = "Public IP of the Headscale instance"
}

output "headscale_url" {
  value       = "https://${var.headscale_hostname}"
  description = "Headscale base URL"
}
