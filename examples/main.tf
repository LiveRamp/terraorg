# Copyright 2019-2020 LiveRamp Holdings, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

provider "okta" {
  # note: specify OKTA_ORG_NAME via environment
  # note: specify OKTA_BASE_URL via environment
  # note: specify OKTA_API_TOKEN via environment
}

provider "gsuite" {
  oauth_scopes = [
    "https://www.googleapis.com/auth/admin.directory.group",
  ]
  impersonated_user_email = "g.suite.admin@yourcompany.com"
}

terraform {
  backend "gcs" {
    bucket = "terraorg-state"
    prefix = ""
  }

  required_version = "~> 0.12.0"
}
