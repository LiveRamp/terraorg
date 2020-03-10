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

require 'terraorg/model/squad'

class Squads
  SCHEMA_VERSION = 'v1'.freeze

  def initialize(parsed_data, people, gsuite_domain, slack_domain)
    version = parsed_data.fetch('version')
    raise "Unsupported squads schema version: #{version}" if version != SCHEMA_VERSION

    @squads = {}
    parsed_data.fetch('squads').each do |squad|
      id = squad.fetch('id')
      @squads[id] = Squad.new(id, squad, people, gsuite_domain, slack_domain)
    end
  end

  def all_names
    @squads.keys
  end

  def lookup!(name)
    @squads.fetch(name)
  end

  def to_h
    { 'version' => SCHEMA_VERSION, 'squads' => @squads.values.sort_by(&:id).map(&:to_h) }
  end
end
