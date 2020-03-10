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

require 'date'
require File.expand_path(File.join('lib', 'terraorg', 'version.rb'))

Gem::Specification.new do |gem|
  gem.name    = 'terraorg'
  gem.version = Terraorg::VERSION
  gem.date    = Date.today.to_s

  gem.summary = "terraorg"
  gem.description = "Manage an organizational structure with Okta and G-Suite using Terraform"

  gem.authors  = ['Joshua Kwan']
  gem.email    = 'joshk@triplehelix.org'
  gem.homepage = 'https://github.com/LiveRamp/terraorg'
  gem.license  = 'MIT'

  gem.required_ruby_version = '>= 2.3'

  gem.add_dependency 'faraday', '~> 1'
  gem.add_dependency 'neatjson', '~> 0.9'
  gem.add_dependency 'oktakit', '~> 0.2'

  # ensure the gem is built out of versioned files
  gem.files = Dir['{bin,lib}/**/*', 'README*', 'LICENSE*']
  gem.executables = ['terraorg']
  gem.require_paths = ['lib']
end
