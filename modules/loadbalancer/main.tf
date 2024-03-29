# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
terraform {}

data "google_dns_managed_zone" "altnames" {
  for_each = {
    for spec in var.dns_altnames:
    "${spec.project}/${spec.zone}" => spec
  }
  project = each.value.project
  name    = each.value.name
}

resource "random_string" "tls" {
  length  = 6
  special = false
  upper   = false

  keepers = {
    domains = join(";", sort(concat(
      ["${var.acme_domain}."],
      [for spec in var.dns_altnames: spec.name]
    )))
  }
}

resource "google_compute_managed_ssl_certificate" "tls" {
  project = var.project 
  name    = "${var.name}-${random_string.tls.result}"

  lifecycle {
    create_before_destroy = true
  }

  managed {
    domains = concat(
      ["${var.acme_domain}."],
      [for spec in var.dns_altnames: spec.name]
    )
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
    hosts = concat(
      [var.acme_domain],
      [for spec in var.dns_altnames: spec.name]
    )
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
  ssl_certificates  = [google_compute_managed_ssl_certificate.tls.self_link]
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

resource "google_dns_record_set" "altnames" {
  depends_on    = [
    data.google_dns_managed_zone.altnames,
    google_compute_global_address.ipv4
  ]
  for_each      = {
    for spec in var.dns_altnames:
    spec.name => merge(spec, {
      ref = "${spec.project}/${spec.zone}"
    })
  }
  managed_zone  = each.value.zone
  project       = each.value.project
  name          = "${each.value.name}."
  type          = "A"
  ttl           = 60
  rrdatas       = [for spec in google_compute_global_address.ipv4: spec.address]
}