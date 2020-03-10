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

require 'terraorg/model/people'
require 'terraorg/model/util'

class Squad
  attr_accessor :id, :name, :metadata, :teams

  class Team
    attr_accessor :location, :members

    def initialize(parsed_data, people)
      @location = parsed_data.fetch('location')
      @members = parsed_data.fetch('members', []).map do |n|
        people.get_or_create!(n)
      end
    end

    # Output a canonical (sorted, formatted) version of this Team.
    # - Sort the members in each team
    def to_h
      { 'location' => @location, 'members' => @members.map(&:id).sort }
    end

    def to_md
      "**#{@location}**: #{@members.map(&:name).sort.join(', ')}"
    end
  end

  def initialize(id, parsed_data, people, gsuite_domain, slack_domain)
    @gsuite_domain = gsuite_domain
    @slack_domain = slack_domain
    @id = id
    @metadata = parsed_data.fetch('metadata', {})
    @name = parsed_data.fetch('name')
    @people = people

    teams_arr = parsed_data.fetch('team', []).map do |t|
      Team.new(t, people)
    end
    @teams = Hash[teams_arr.map { |t| [t.location, t] }]
  end

  def members(location: nil)
    @teams.select { |l, t|
      location == nil || l == location
    }.map { |l, t|
      t.members
    }.flatten
  end

  def get_acl_groups(org_id)
    # each geographically located subteam
    groups = Hash[@teams.map { |location, team|
      [unique_name(org_id, location), {'name' => "#{@name} squad members based in #{location}", 'members' => team.members}]
    }]

    # combination of all subteams
    groups[unique_name(org_id, nil)] = {'name' => "#{@name} squad worldwide members", 'members' => members}

    groups
  end

  def unique_name(org_id, location)
    if location
      "#{org_id}-squad-#{@id}-#{location.downcase}"
    else
      "#{org_id}-squad-#{@id}"
    end
  end

  def validate!
    raise 'Squad has no members' if members.size == 0
  end

  def to_md(platoon_name, org_id)
    pm = @metadata.fetch('pm', [])
    pm = pm.map { |p| @people.get_or_create!(p).name }.join(', ')

    sme = @metadata.fetch('sme', '')
    if !sme.empty?
      sme = @people.get_or_create!(sme).name
    end

    epo = @metadata.fetch('epo', '')
    if !epo.empty?
      epo = @people.get_or_create!(epo).name
    end

    manager = @metadata.fetch('manager', '')
    if !manager.empty?
      manager = @people.get_or_create!(manager).name
    end

    subteam_members = @teams.values.map(&:to_md).join(' / ')
    email = "#{unique_name(org_id, nil)}@#{@gsuite_domain}"
    slack = @metadata.fetch('slack', '')
    if slack
      slack = "[#{slack}](https://#{@slack_domain}/app_redirect?channel=#{slack.gsub(/^#/, '')})"
    end
    # platoon name, squad name, PM, email list, SME, slack, # people, squad manager, eng product owner, members
    "|#{platoon_name}|#{@name}|#{pm}|[#{email}](#{email})|#{sme}|#{slack}|#{members.size}|#{manager}|#{epo}|#{subteam_members}|"
  end

  def generate_tf(org_id)
    groups = get_acl_groups(org_id)

    groups.map { |id, group|
      description = "#{group.fetch('name')} (terraorg)"
      <<-EOF
resource "okta_group" "#{id}" {
  name = "#{id}"
  description = "#{description}"
  users = #{Util.persons_tf(group.fetch('members'))}
}

#{Util.gsuite_group_tf(id, @gsuite_domain, group.fetch('members'), description)}
EOF
    }.join("\n\n")
  end

  def to_h
    # Output a canonical (sorted, formatted) version of this Squad.
    # - Subteams are sorted by location lexically
    obj = { 'id' => @id, 'name' => @name }
    obj['team'] = @teams.values.sort_by { |t| t.location }.map(&:to_h)
    obj['metadata'] = @metadata if @metadata

    obj
  end
end
