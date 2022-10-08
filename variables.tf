# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "api_config" {
  default = {}
  type    = object({
    scope: string
    resources: map(any)
  })
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

variable "http_loglevel" {
  default     = "CRITICAL"
  type        = string
  description = "Specifies the log level used by the HTTP server."
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

variable "name_prefix" {
  type    = string
  default = null
}

variable "oauth_allow_client_id" {
  description = "Allow the client to specify the `client_id` parameter."
  type        = bool
  default     = false
}

variable "oauth_allow_claims" {
  description = "Allow the client to specify the `claims` parameter."
  type        = bool
  default     = false
}

variable "oauth_allow_redirect_uri" {
  description = "Allow the client to specify the `redirect_uri` parameter."
  type        = bool
  default     = false
}

variable "oauth_client_id" {
  type = string
}

variable "oauth_image" {
  type    = string
  default = "europe-docker.pkg.dev/unimatrixops/webid/agent@sha256:d7ad1f35a614d92c631b3cfd57818bc0a947d047319edb366030cd7f4dc4b088"
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

variable "ping_locations" {
  type    = list(string)
  default = ["europe-west1"]
}

variable "ping_schedule" {
  type    = string
  default = null
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
