variable "project_id" {
  type        = string
  description = "GCP project id (same project as labs)"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "zone" {
  type        = string
  description = "GCP zone"
}

variable "name" {
  type        = string
  description = "Runner VM name"
  default     = "lab-factory-runner"
}

variable "machine_type" {
  type        = string
  description = "GCE machine type"
  default     = "e2-medium"
}

variable "github_repo" {
  type        = string
  description = "GitHub repo slug (org/repo) to register the runner against"
}

variable "github_token_secret_name" {
  type        = string
  description = "Secret Manager secret name containing a GitHub runner registration token"
  default     = "github_runner_token"
}

variable "labels" {
  type        = map(string)
  description = "GCE labels"
  default     = {}
}

variable "runner_labels" {
  type        = string
  description = "Comma-separated GitHub runner labels"
  default     = "self-hosted,gcp,lab-factory"
}
