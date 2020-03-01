require 'terraorg/model/util'

class Org
  MAX_SQUADS_PER_PERSON = 2
  SCHEMA_VERSION = 'v1'.freeze

  def initialize(parsed_data, platoons, squads, people, gsuite_domain)
    @people = people
    @id = parsed_data.fetch('id')
    @name = parsed_data.fetch('name')
    @metadata = parsed_data.fetch('metadata', {})
    @manager = @people.get_or_create!(parsed_data.fetch('manager'))
    @manager_location = parsed_data.fetch('manager_location')
    # @member_exception_people is a Hash of Squad::Teams, like the teams attribute in a Squad.
    @member_exception_people = Hash[parsed_data.fetch('exception_people').map { |p|
      [p.fetch('location'), Squad::Team.new(p, @people)]
    }]
    @member_exception_squad_names = []
    @member_exception_squads = parsed_data.fetch('exception_squads').map do |s|
      @member_exception_squad_names.push(s)
      squads.lookup!(s)
    end
    @member_platoon_names = []
    @member_platoons = parsed_data.fetch('platoons').map do |p|
      @member_platoon_names.push(p)
      platoons.lookup!(p)
    end

    # used to generate a group
    @gsuite_domain = gsuite_domain

    # used for validate!
    @platoons = platoons
    @squads = squads
  end

  def validate!
    # Do not allow the JSON files to contain any people who have left.
    raise "Users have left the company: #{@people.inactive.map(&:id).join(', ')}" unless @people.inactive.empty?

    # Do not allow the org to be totally empty.
    raise 'Org has no platoons or exception squads' if @member_platoons.size + @member_exception_squads.size == 0

    # Require all platoons to be part of the org.
    platoon_diff = Set.new(@platoons.all_names) - Set.new(@member_platoon_names)
    unless platoon_diff.empty?
      raise "Platoons are not used in the org: #{platoon_diff.to_a.sort}"
    end

    # Require all squads to be used in the org.
    squad_diff = Set.new(@squads.all_names) - Set.new(@platoons.all_squad_names) - Set.new(@member_exception_squad_names)
    unless squad_diff.empty?
      raise "Squad(s) are not used in the org: #{squad_diff.to_a.sort}"
    end

    all_squads = (@member_platoons.map(&:member_squads) + @member_exception_squads).flatten
    seen_squads = {}

    # Validate that a squad is not part of more than one platoon
    all_squads.map(&:id).each do |id|
      seen_squads[id] = seen_squads.fetch(id, 0) + 1
    end
    more_than_one_platoon = seen_squads.select do |squad, count|
      count > 1
    end
    if !more_than_one_platoon.empty?
      raise "Squads are part of more than one platoon: #{more_than_one_platoon}"
    end

    # Validate that a squad member belongs to at most two squads in the entire org
    squad_count = {}
    all_squads.map(&:teams).flatten.map(&:values).flatten.map(&:members).flatten.each do |member|
      squad_count[member.id] = squad_count.fetch(member.id, 0) + 1
    end
    more_than_max_squads = squad_count.select do |member, count|
      count > MAX_SQUADS_PER_PERSON
    end
    if !more_than_max_squads.empty?
      # TODO(joshk): Enforce after consulting with Sean
      $stderr.puts "WARNING: Members are part of more than #{MAX_SQUADS_PER_PERSON} squads: #{more_than_max_squads}"
    end

    # Validate that a squad member is not also an org exception
    exceptions = Set.new(@member_exception_people.map { |_, t| t.members }.flatten.map(&:id))
    exception_and_squad_member = squad_count.keys.select do |member|
      exceptions.member? member
    end
    if !exception_and_squad_member.empty?
      raise "Exception members are also squad members: #{exception_and_squad_member}"
    end
  end

  def members
    Set.new([@manager] + (@member_platoons + @member_exception_squads).map(&:members).flatten + @member_exception_people.map { |_, t| t.members }.flatten).to_a
  end

  def get_acl_groups(attr: :id)
    # Return a LIST_NAME => [MEMBER1, MEMBER2...] hash of ACL groups
    { unique_name => members.map(&attr).sort }.
      merge(get_platoon_acl_groups(attr: attr)).
      merge(get_exception_squad_acl_groups(attr: attr))
  end

  def get_platoon_acl_groups(attr: :id)
    @member_platoons.map { |p| p.get_acl_groups(@id, attr: attr) }.reduce({}, :merge)
  end

  def get_exception_squad_acl_groups(attr: :id)
    @member_exception_squads.map { |p| p.get_acl_groups(@id) }.map(&attr).reduce({}, :merge)
  end

  def unique_name
    "#{@id}-all"
  end

  def get_platoons_md
    # 90 degree rotated version of the Platoons page of the legacy Engineering Squads sheet
    # Format:
    # Platoon,Total,Members
    # [ORG_HUMAN_NAME],[COUNT]
    # [PLAT1_HUMAN_NAME],[PLAT1_COUNT],[PLAT1_MEMBER1],[PLAT1_MEMBER2],...
    # [PLAT2_HUMAN_NAME],[PLAT2_COUNT],[PLAT2_MEMBER1],[PLAT2_MEMBER2],...
    md_lines = [
      '# Engineering Platoons List',
      '',
      '|Platoon|Manager|Total|Members|',
      '|---|---|---|---|',
      "|_#{@name} Total_|#{@manager.name}|#{members.size}|",
    ]
    md_lines += @member_platoons.map(&:get_platoons_psv_row)

    raise "Users have left the company: #{@people.inactive.map(&:id).join(', ')}" unless @people.inactive.empty?
    md_lines.join("\n")
  end

  def get_squads_md
    # Format:
    # platoon name, squad name, PM, email list, SME, slack, # people, squad manager, eng product owner, members
    md_lines = [
      '# Engineering Squads List',
      '',
      '|Platoon|Squad|PM|Mailing list|TS SME|Slack|# Engineers|Squad Manager|Eng Product Owner|Members|',
      '|---|---|---|---|---|---|---|---|---|---|',
    ]
    md_lines += @member_platoons.map { |s| s.get_squads_psv_rows(@id) }
    md_lines += @member_exception_squads.map { |s| s.to_md('_No Platoon_', @id) }
    md_lines.push "|_No Platoon_|_No Squad_|||||#{@member_exception_people.size}|||#{@member_exception_people.values.map(&:to_md).join(' / ')}|"

    raise "Users have left the company: #{@people.inactive.map(&:id).join(', ')}" unless @people.inactive.empty?
    md_lines.join("\n")
  end

  def generate_tf
    tf = @member_platoons.map { |p| p.generate_tf(@id) }.join("\n")
    File.write('auto.platoons.tf', tf)

    tf = @member_exception_squads.map { |s| s.generate_tf(@id) }.join("\n")
    File.write('auto.exception_squads.tf', tf)

    # Roll all platoons and exception squads into the org.
    roll_up_to_org = \
      @member_exception_squads.map { |s| s.unique_name(@id, nil) } + \
      @member_platoons.map { |p| p.unique_name(@id) }

    # Generate the org, which contains:
    # - exception people (added manually to group)
    # - the org manager (added manually to group)
    # - all the platoons (via rule)
    # - all exception squads (via rule)
    org_condition = roll_up_to_org.map {
      |n| "\\\"${okta_group.#{n}.id}\\\""
    }.join(',')

    description = "#{@name} organization worldwide members (terraorg)"
    tf = <<-EOF
# Okta for Organization: #{@name}
resource "okta_group" "#{unique_name}" {
  name = "#{unique_name}"
  description = "#{description}"
  users = #{Util.persons_tf(members)}
}

#{Util.gsuite_group_tf(unique_name, @gsuite_domain, members, description)}
EOF

    # Generate a special group for all org members grouped by country
    all_squads = (@member_platoons.map(&:member_squads) + @member_exception_squads).flatten
    all_locations = {}
    (all_squads.map(&:teams).flatten + [@member_exception_people]).each do |team|
      team.each do |location, subteam|
        all_locations[location] = all_locations.fetch(location, Set.new).merge(subteam.members)
      end
    end

    # Manually add the manager to a specific location
    all_locations[@manager_location] = all_locations.fetch(@manager_location, Set.new).add(@manager)

    all_locations.each do |l, m|
      name = "#{unique_name}-#{l.downcase}"
      tf += <<-EOF
resource "okta_group" "#{name}" {
  name = "#{name}"
  description = "#{@name} organization members based in #{l} (terraorg)"
  users = #{Util.persons_tf(m)}
}
EOF
    end

    File.write('auto.org.tf', tf)
  end

  # Output a canonical (sorted, formatted) version of this organization.
  # - Sort the platoon names lexically
  # - Sort the exception squad ids lexically
  # - Sort the exception people ids lexically
  def to_h
    obj = { 'version' => SCHEMA_VERSION, 'id' => @id, 'name' => @name, 'manager_location' => @manager_location, 'manager' => @manager.id }
    obj['platoons'] = @platoons.all.map(&:id).sort
    if @metadata
      obj['metadata'] = @metadata
    end
    if @member_exception_people
      obj['exception_people'] = @member_exception_people.values.sort_by(&:location).map(&:to_h)
    end
    if @member_exception_squads
      obj['exception_squads'] = @member_exception_squads.map(&:id).sort
    end

    obj
  end
end