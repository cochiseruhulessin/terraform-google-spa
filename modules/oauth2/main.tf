# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

# Create the service account that is used by the service to
# access resources.
resource "random_string" "service_account" {
  length    = 6
  special   = false
  upper     = false
}

resource "google_service_account" "default" {
  project       = var.project
  account_id    = "oauth-token-handler-${random_string.service_account.result}"
  display_name  = "OAuth 2.x Token Handler"
}

# Create a keyring with a signing key and an asymmetric encryption
# key. These keys are used by the OAuth 2.x client to identify itself
# and receive encrypted data.
resource "google_kms_key_ring" "default" {
  project    = var.project
  name       = var.keyring_name
  location   = var.keyring_location
}

resource "google_kms_key_ring_iam_binding" "viewer" {
  key_ring_id = google_kms_key_ring.default.id
  role        = "roles/cloudkms.viewer"
  members     = ["serviceAccount:${google_service_account.default.email}"]
}

resource "google_kms_key_ring_iam_binding" "operator" {
  key_ring_id = google_kms_key_ring.default.id
  role        = "roles/cloudkms.cryptoOperator"
  members     = ["serviceAccount:${google_service_account.default.email}"]
}

resource "google_kms_crypto_key" "sig" {
  depends_on      = [google_kms_key_ring.default]
  name            = "oauth-client-signing-key"
  key_ring        = google_kms_key_ring.default.id
  purpose         = "ASYMMETRIC_SIGN"

  version_template {
    algorithm         = "EC_SIGN_P384_SHA384"
    protection_level  = "SOFTWARE"
  }
}

resource "google_kms_crypto_key" "enc" {
  depends_on      = [google_kms_key_ring.default]
  name            = "oauth-client-encryption-key"
  key_ring        = google_kms_key_ring.default.id
  purpose         = "ASYMMETRIC_DECRYPT"

  version_template {
    algorithm         = "RSA_DECRYPT_OAEP_3072_SHA256"
    protection_level  = "SOFTWARE"
  }
}

resource "google_kms_crypto_key" "cookie" {
  depends_on      = [google_kms_key_ring.default]
  name            = "cookie-encryption-key"
  key_ring        = google_kms_key_ring.default.id
  purpose         = "ENCRYPT_DECRYPT"

  version_template {
    algorithm         = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level  = "SOFTWARE"
  }
}

# Create a secret to hold the API gateway configuration, which
# is mounted inside the Cloud Run instance as a file.
resource "google_secret_manager_secret" "gateway-config" {
  project     = var.project
  secret_id   = "oauth-token-handler-config-${var.suffix}"

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_iam_binding" "secretAccessor" {
  project     = google_secret_manager_secret.gateway-config.project
  secret_id   = google_secret_manager_secret.gateway-config.secret_id
  role        = "roles/secretmanager.secretAccessor"
  members     = ["serviceAccount:${google_service_account.default.email}"]
}

resource "google_secret_manager_secret_version" "gateway-config" {
  secret      = google_secret_manager_secret.gateway-config.id
  secret_data = yamlencode(var.api_config)
}

# Create the Cloud Run service, a backend, network endpoint
# group.
resource "google_cloud_run_service" "default" {
  depends_on                  = [google_secret_manager_secret_iam_binding.secretAccessor]
  for_each                    = toset(var.locations)
  project                     = var.project
  name                        = "oauth2-token-handler-${var.suffix}"
  location                    = each.key
  autogenerate_revision_name  = true

  metadata {
    annotations = {
      "run.googleapis.com/ingress": "internal-and-cloud-load-balancing"
    }
    namespace = var.project
  }

  template {
    spec {
      container_concurrency = 100
      service_account_name  = google_service_account.default.email

      containers {
        image = var.image
        args = ["runhttp"]

        ports {
          name            = "http1"
          container_port  = 8000
        }

        resources {
          limits = {
            cpu = "${var.cpu_count}000m"
            memory: "512Mi"
          }
        }

        env {
          name  = "COOKIE_ENCRYPTION_KEY"
          value = "google://cloudkms.googleapis.com/${google_kms_crypto_key.cookie.id}"
        }

        env {
          name  = "OAUTH_CLIENT_ENCRYPTION_KEY"
          value = "google://cloudkms.googleapis.com/${google_kms_crypto_key.enc.id}"
        }

        env {
          name  = "OAUTH_CLIENT_SIGNING_KEY"
          value = "google://cloudkms.googleapis.com/${google_kms_crypto_key.sig.id}"
        }

        env {
          name  = "DEPLOYMENT_ENV"
          value = var.deployment_env
        }

        # TODO: We assume here that the container is only ever
        # running behind a Google load balancer.
        env {
          name  = "FORWARDED_ALLOW_IPS"
          value = "*"
        }

        env {
          name  = "GOOGLE_HOST_PROJECT"
          value = var.project
        }

        env {
          name  = "GOOGLE_SERVICE_ACCOUNT_EMAIL"
          value = google_service_account.default.email
        }

        env {
          name  = "HTTP_LOGLEVEL"
          value = var.http_loglevel
        }

        env {
          name  = "HTTP_WORKERS"
          value = var.cpu_count
        }

        env {
          name  = "OAUTH_ALLOW_CLAIMS"
          value = (var.allow_claims) ? "1" : "0"
        }

        env {
          name  = "OAUTH_CLIENT"
          value = var.client_id
        }

        env {
          name  = "OAUTH_REDIRECT_URL"
          value = var.redirect_uri
        }

        env {
          name  = "OAUTH_SCOPE"
          value = join(" ", var.scope)
        }

        env {
          name  = "OAUTH_SERVER"
          value = var.server
        }

        env {
          name  = "PYTHONUNBUFFERED"
          value = "True"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      #template.0.spec.0.containers.0.args,
      #template.0.spec.0.containers.0.image,
      metadata[0].annotations["client.knative.dev/user-image"],
      metadata[0].annotations["run.googleapis.com/client-name"],
      metadata[0].annotations["run.googleapis.com/client-version"],
    ]
  }
}

resource "google_compute_region_network_endpoint_group" "endpoint" {
  for_each              = toset(var.locations)
  project               = var.project
  network_endpoint_type = "SERVERLESS"
  region                = each.key
  name                  = "oauth2-token-handler-${var.suffix}"

  cloud_run {
    service = "oauth2-token-handler-${var.suffix}"
  }
}

resource "google_compute_backend_service" "default" {
  project     = var.project
  name        = "oauth2-token-handler-${var.suffix}"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30
  enable_cdn  = false

  dynamic "backend" {
    for_each = google_compute_region_network_endpoint_group.endpoint

    content {
      group = backend.value.self_link
    }
  }

  log_config {
    enable = true
  }
}

# Create an IAM policy to allow invocation and deployment
# by the deployers.
data "google_iam_policy" "default" {
  binding {
    role    = "roles/run.invoker"
    members = toset(concat(var.invokers, [
			"serviceAccount:${google_service_account.default.email}"
		]))
  }

  binding {
    role    = "roles/run.developer"
    members = var.deployers
  }
}

resource "google_cloud_run_service_iam_policy" "default" {
  for_each    = google_cloud_run_service.default
  location    = each.value.location
  project     = each.value.project
  service     = each.value.name
  policy_data = data.google_iam_policy.default.policy_data
}
