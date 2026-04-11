terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "4.29.0"
    }
  }

  backend "s3" {
    bucket                      = "terraform"
    key                         = "terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
    endpoints = { s3 = "https://9d54c96ad75779fd6a8f02cfcab09d50.r2.cloudflarestorage.com" }
  }
}

provider "grafana" {
  url = "https://mauriciofierrom.grafana.net"
  auth = var.grafana_auth
  connections_api_url = "https://connections-api-prod-sa-east-1.grafana.net"
  connections_api_access_token = var.grafana_auth
}

provider "grafana" {
  alias                    = "cloud"
  cloud_access_policy_token = var.grafana_auth
}

resource "grafana_connections_metrics_endpoint_scrape_job" "metrics" {
  stack_id                     = "stopmyhand"
  name                         = "metrics"
  enabled                      = false
  authentication_method        = "bearer"
  authentication_bearer_token  = var.metrics_bearer_token
  url                          = "${var.base_url}/metrics"
  scrape_interval_seconds      = 120
}

resource "grafana_cloud_stack_service_account" "prom_ex" {
  provider   = grafana.cloud
  stack_slug = "stopmyhand"
  name       = "prom-ex-dashboard-uploader"
  role       = "Editor"
}

resource "grafana_cloud_stack_service_account_token" "prom_ex" {
  provider           = grafana.cloud
  stack_slug         = "stopmyhand"
  name               = "prom-ex-dashboard-uploader-token"
  service_account_id = grafana_cloud_stack_service_account.prom_ex.id
}

output "prom_ex_grafana_token" {
  value     = grafana_cloud_stack_service_account_token.prom_ex.key
  sensitive = true
}
