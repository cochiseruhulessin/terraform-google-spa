# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "acme_domain" {
  type = string
}

variable "dns_altnames" {
  type    = list(
    object({
      project = string
      zone    = string
      name    = string
    })
  )
  default = []
}

variable "dns_project" {
  type = string
}

variable "dns_zone" {
  type = string
}

variable "name" {
  type = string
}

variable "oauth_backend_id" {
  type = string
}

variable "project" {
  type = string
}

variable "spa_backend_id" {
  type = string
}