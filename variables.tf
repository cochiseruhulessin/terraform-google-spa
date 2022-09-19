# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "acme_email" {
  type = string
}

variable "api_config" {
  default = {}
}

variable "api_locations" {
  type = list(string)
}

variable "artifact_registry_location" {
  type    = string
  default = null
}

variable "artifact_registry_name" {
  type    = string
  default = null
}

variable "artifact_registry_project" {
  type    = string
  default = null
}

variable "billing_account" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "deployers" {
  type = list(string)
}

variable "deployment_env" {
  type = string
}

variable "dns_project" {
  type = string
}

variable "dns_zone" {
  type = string
}

variable "enable_cdn" {
  type    = bool
  default = true
}

variable "isolate" {
  type    = bool
  default = true
}

variable "keyring_location" {
  type = string
}

variable "location" {
  type = string
}

variable "oauth_allow_claims" {
  description = "Allow the client to specify the `claims` parameter."
  type        = bool
  default     = false
}

variable "oauth_client_id" {
  type = string
}

variable "oauth_image" {
  type    = string
  default = "europe-docker.pkg.dev/unimatrixops/webid/agent@sha256:8043be6ca0cb6951daca04050dfbe2ccf89d03db6ddd86fe78c83d4cf1e92b55"
}

variable "oauth_scope" {
  type = list(string)
}

variable "oauth_callback_path" {
  type    = string
  default = ""
}

variable "oauth_server" {
  type = string
}

variable "org_id" {
  type = string
}

variable "project" {
  type    = string
}

variable "service_id" {
  type = string
}

variable "service_name" {
  type = string
}

variable "with_dns" {
  type    = bool
  default = false
}

variable "with_loadbalancer" {
  type    = bool
  default = false
}