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
    tls = {
      version = "3.1.0"
    }
  }
}

resource "tls_private_key" "acme" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "acme_registration" "default" {
  account_key_pem = tls_private_key.acme.private_key_pem
  email_address   = var.acme_email
}

resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "csr" {
  depends_on = [tls_private_key.server]
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.server.private_key_pem
  dns_names       = [var.acme_domain]

  subject {
    country             = "NL"
    province            = "Gelderland"
    locality            = "Wezep"
    organization        = "Unimatrix One B.V."
    organizational_unit = "PKI"
    common_name         = var.acme_domain
  }
}

resource "acme_certificate" "crt" {
  depends_on              = [
    acme_registration.default,
    tls_private_key.acme,
    tls_private_key.server
  ]
  account_key_pem         = tls_private_key.acme.private_key_pem
  certificate_request_pem = tls_cert_request.csr.cert_request_pem
  min_days_remaining      = 30
  recursive_nameservers   = ["8.8.8.8:53"]

  dns_challenge {
    provider = "gcloud"

    config = {
      GCE_PROJECT = var.dns_project
    }
  }
}

resource "google_compute_ssl_certificate" "tls" {
  depends_on  = [tls_private_key.server]
  project     = var.project
  name_prefix = var.name
  private_key = tls_private_key.server.private_key_pem
  certificate = "${acme_certificate.crt.certificate_pem}${acme_certificate.crt.issuer_pem}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_url_map" "redirect" {
  project = var.project
  name    = "${var.name}-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_url_map" "urls" {
  project               = var.project
  name                  = var.name
  default_service       = var.spa_backend_id

  host_rule {
    hosts = [var.acme_domain]
    path_matcher = "spa"
  }

  path_matcher {
    name = "spa"
    default_service = var.spa_backend_id

    path_rule {
      paths = [
        "/api",
        "/api/*",
      ]
      service = var.oauth_backend_id
    }
  }
}

resource "google_compute_target_http_proxy" "default" {
  project = var.project
  name    = "${var.name}-redirect"
  url_map = google_compute_url_map.redirect.self_link
}

resource "google_compute_target_https_proxy" "default" {
  depends_on        = [google_compute_url_map.urls]
  project           = var.project
  provider          = google
  name              = var.name
  url_map           = google_compute_url_map.urls.self_link
  ssl_certificates  = [google_compute_ssl_certificate.tls.self_link]
}

resource "google_compute_global_address" "ipv4" {
  count     = 1
  project   = var.project
  provider  = google
  name      = "${var.name}-${count.index + 1}"
}

resource "google_compute_global_forwarding_rule" "http" {
  depends_on            = [google_compute_global_address.ipv4]
  count                 = 1
  provider              = google
  project               = var.project
  name                  = "${var.name}-redirect-${count.index+1}"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.ipv4[count.index].address
  ip_protocol           = "TCP"
  port_range            = "80"
  target                = google_compute_target_http_proxy.default.self_link
}

resource "google_compute_global_forwarding_rule" "https" {
  depends_on            = [google_compute_global_address.ipv4]
  count                 = 1
  provider              = google
  project               = var.project
  name                  = "${var.name}-${count.index+1}"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.ipv4[count.index].address
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.default.self_link
}

resource "google_dns_record_set" "dns" {
  managed_zone  = var.dns_zone
  project       = var.dns_project
  name          = "${var.acme_domain}."
  type          = "A"
  ttl           = 60
  rrdatas       = [for spec in google_compute_global_address.ipv4: spec.address]
}