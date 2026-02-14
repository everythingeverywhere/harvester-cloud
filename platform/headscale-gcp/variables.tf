variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "zone" {
  type        = string
  description = "GCP zone"
}

variable "machine_type" {
  type        = string
  description = "Compute Engine machine type"
  default     = "e2-small"
}

variable "headscale_hostname" {
  type        = string
  description = "FQDN for Headscale (must resolve to the instance public IP for Let's Encrypt)"
}

variable "letsencrypt_email" {
  type        = string
  description = "Email used for Let's Encrypt registration"
}

variable "headscale_version" {
  type        = string
  description = "Headscale version (GitHub release tag)"
  default     = "0.23.0"
}

variable "create_dns_record" {
  type        = bool
  description = "If true, create a Cloud DNS A record in the given managed zone"
  default     = false
}

variable "dns_managed_zone" {
  type        = string
  description = "Cloud DNS managed zone name (required if create_dns_record=true)"
  default     = null
}
