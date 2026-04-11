variable "grafana_auth" {
  type = string
  description = "Grafana API Token"
  sensitive = true
}

variable "metrics_bearer_token" {
  type = string
  description = "Bearer token to authenticate against the metrics endpoint"
  sensitive = true
}

variable "base_url" {
  type = string
  description = "The metrics application base url"
}
