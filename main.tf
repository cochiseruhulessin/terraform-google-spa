# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
terraform {
  required_providers {
    acme = {
      source = "vancluever/acme"
      version = "2.6.0"
    }
    google = {
      source  = "google"
      version = "4.30.0"
    }
  }
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

locals {
  project = (var.isolate) ? google_project.service[0].project_id : var.project
}

resource "google_project_service" "required" {
  for_each = toset(
    concat([
      "cloudkms.googleapis.com",
      "cloudscheduler.googleapis.com",
      "compute.googleapis.com",
      "run.googleapis.com",
      "secretmanager.googleapis.com",
    ]
  ))
  project            = local.project
  service            = each.key
  disable_on_destroy = false
}

# Generate a random suffic for the service-specific project and create
# a project holding the resources specific to this service.
resource "random_string" "project_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "google_project" "service" {
  count           = (var.isolate) ? 1 : 0
  name            = var.service_name
  project_id      = "${(var.name_prefix != null) ? var.name_prefix : var.project}-${random_string.project_suffix.result}"
  billing_account = var.billing_account
  org_id          = var.org_id
}

# Create a bucket to hold the assets and a corresponding backend
# service with the proper headers configured.
resource "google_storage_bucket" "assets" {
  project                     = local.project
  name                        = var.bucket_name
  location                    = var.location
  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page = "index.html"
  }
}

resource "google_storage_bucket_iam_binding" "public" {
  bucket = google_storage_bucket.assets.name
  role = "roles/storage.legacyObjectReader"
  members = ["allUsers"]
}

resource "google_compute_backend_bucket" "backend" {
  depends_on  = [google_project_service.required]
  project     = local.project
  name        = "spa-${var.service_id}-${random_string.project_suffix.result}"
  description = "Backend bucket for SPA ${var.service_id}"
  bucket_name = google_storage_bucket.assets.name
  enable_cdn  = var.enable_cdn

  # We don't trust the browser code, but this still leaves a too large
  # attack surface (TODO).
  custom_response_headers = [
    "Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'",
    "Referrer-Policy: no-referrer",
    "Strict-Transport-Security: max-age=15552000; includeSubDomains",
    "X-Content-Type-Options: nosniff",
    "X-Frame-Options: SAMEORIGIN",
  ]
}

module "oauth2" {
  depends_on        = [google_project_service.required]
  allow_client_id   = var.oauth_allow_client_id
  allow_claims      = var.oauth_allow_claims
  api_config        = var.api_config
  client_id         = var.oauth_client_id
  deployers         = var.deployers
  deployment_env    = var.deployment_env
  http_loglevel     = var.http_loglevel
  image             = var.oauth_image
  keyring_name      = "${var.service_id}-${random_string.project_suffix.result}"
  keyring_location  = var.keyring_location
  locations         = var.api_locations
  project           = local.project
  redirect_uri      = "https://${var.bucket_name}${var.oauth_callback_path}"
  scope             = var.oauth_scope
  server            = var.oauth_server
  source            = "./modules/oauth2"
  suffix            = random_string.project_suffix.result
}

module "loadbalancer" {
  depends_on    = [
    google_compute_backend_bucket.backend,
    module.oauth2
  ]
  count             = (var.with_loadbalancer) ? 1 : 0
  source            = "./modules/loadbalancer"
  acme_domain       = var.bucket_name
  dns_project       = var.dns_project
  dns_zone          = var.dns_zone
  name              = "${var.service_id}-${random_string.project_suffix.result}"
  oauth_backend_id  = module.oauth2.backend_id
  project           = local.project
  spa_backend_id    = google_compute_backend_bucket.backend.id
}

module "dns" {
  count       = (var.with_dns) ? 1 : 0
  source      = "./modules/dns"
  dns_project = var.dns_project
  dns_zone    = var.dns_zone
}

resource "google_cloud_scheduler_job" "keepalive" {
  depends_on        = [google_project_service.required]
  for_each          = toset((var.ping_schedule == null) ? [] : var.ping_locations)
  project           = local.project
  name              = "${var.service_id}-${random_string.project_suffix.result}-keepalive"
  attempt_deadline  = "30s"
  schedule          = var.ping_schedule
  region            = each.key

  http_target {
    http_method = "GET"
    uri         = "https://${var.bucket_name}/api/oauth/v2/jwks.json"
  }
}
