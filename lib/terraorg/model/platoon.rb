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

require 'terraorg/model/util'

class Platoon
  attr_accessor :id, :name, :member_exceptions, :member_squads

  def initialize(parsed_data, squads, people, gsuite_domain)
    @id = parsed_data.fetch('id')
    @metadata = parsed_data.fetch('metadata', {})
    @name = parsed_data.fetch('name')
    @manager = people.get_or_create!(parsed_data.fetch('manager'))
    @member_exceptions = parsed_data.fetch('exceptions', []).map do |n|
      people.get_or_create!(n)
    end
    @member_squad_names = []
    @member_squads = parsed_data.fetch('squads').map do |s|
      @member_squad_names.push(s)
      squads.lookup!(s)
    end
    @gsuite_domain = gsuite_domain
  end

  def validate!
    raise 'Platoon has no squads' if @member_squads.size == 0
  end

  def squad_names
    @member_squad_names
  end

  def members
    Set.new([@manager] + @member_squads.map(&:members).flatten + @member_exceptions).to_a
  end

  def unique_name(org_id)
    "#{org_id}-platoon-#{@id}"
  end

  def get_acl_groups(org_id, platoon: true)
    if platoon
      rv = { unique_name(org_id) => {'name' => "#{@name} platoon members worldwide", 'members' => members} }
    else
      rv = {}
    end

    @member_squads.map { |s| s.get_acl_groups(org_id) }.reduce(rv, :merge)
  end

  def get_platoons_psv_row
    "|#{@name}|#{@manager.name}|#{members.size}|#{members.map(&:name).sort.join(', ')}|"
  end

  def get_squads_psv_rows(org_id)
    @member_squads.map { |s| s.to_md(@name, org_id) }
  end

  def generate_tf(org_id)
    tf_id = unique_name(org_id)

    # tf formatted, comma separated references to the group ids for the
    # squads in this platoon
    squads_condition = get_acl_groups(org_id, platoon: false).map {
      |n, _| "\\\"${okta_group.#{n}.id}\\\""
    }.join(',')

    # tf containing the platoon declaration
    description = "#{@name} platoon members (terraorg)"
    rv = <<-EOF
# Platoon: #{@name}
# Squads: #{squad_names.join(', ')}

resource "okta_group" "#{tf_id}" {
  name = "#{tf_id}"
  description = "#{description}"
  users = #{Util.persons_tf(members)}
}

#{Util.gsuite_group_tf(tf_id, @gsuite_domain, members, description)}
EOF

    # tf containing squads and their members
    rv += @member_squads.map { |s| s.generate_tf(org_id) }.join("\n")
  end

  # Output a canonical (sorted, formatted) version of this object.
  # - Sort the squad ids lexically
  # - Sort the exceptions lexically
  def to_h
    obj = { 'id' => @id, 'name' => @name, 'manager' => @manager.id, 'squads' => @member_squads.map(&:id) }
    unless @member_exceptions.empty?
      obj['exceptions'] = @member_exceptions.map(&:id)
    end
    unless @metadata.empty?
      obj['metadata'] = @metadata
    end

    obj
  end
end
