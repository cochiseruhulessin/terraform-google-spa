# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "allow_claims" {
  type        = bool
  default     = false
}

variable "allow_client_id" {
  type        = bool
  default     = false
}

variable "api_config" {
  default = {}
}

variable "client_id" {
  type = string
}

variable "cpu_count" {
  type    = number
  default = 1
}

variable "deployers" {
  type = list(string)
}

variable "deployment_env" {
  type = string
}

variable "http_loglevel" {
  type        = string
}

variable "invokers" {
  type = list(string)
  default = ["allUsers"]
}

variable "image" {
  type = string
}

variable "keyring_location" {
  type = string
}

variable "keyring_name" {
  type = string
}

variable "locations" {
  type = list(string)
}

variable "project" {
  type = string
}

variable "redirect_uri" {
  type = string
}

variable "scope" {
  type = list(string)
}

variable "server" {
  type = string
}

variable "suffix" {
  type = string
}