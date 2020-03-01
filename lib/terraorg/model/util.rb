class Util
  # Take a list of Persons and turn it into a newline delimited, comma
  # separated array definition suitable for inclusion in terraform. Each line
  # contains an okta id and a comment indicating the person's name.
  def self.persons_tf(persons)
    "[\n" + persons.map { |p| "    \"#{p.okta_id}\", # #{p.name}" }.join("\n") + "\n]\n"
  end

  # Take a list of Persons and generate a gsuite_group containing all of those
  # members with expected organizational settings.
  def self.gsuite_group_tf(name, domain, persons, description)
    tf = <<-TERRAFORM
# G Suite group for #{email}
resource "gsuite_group" "#{name}" {
  email = "#{name}@#{domain}"
  name  = "#{name}"
  description = "#{description}"
}

# TODO(joshk): Disabled for now.
# resource "gsuite_group_settings" "#{name}" {
#   email = "${gsuite_group.#{name}.email}"
#   who_can_discover_group = "ALL_IN_DOMAIN_CAN_DISCOVER"
#   who_can_view_membership = "ALL_IN_DOMAIN_CAN_VIEW"
#   who_can_leave_group = "NONE_CAN_LEAVE"
#   who_can_join = "INVITED_CAN_JOIN"
#   who_can_post_message = "ALL_IN_DOMAIN_CAN_POST"
# }

resource "gsuite_group_members" "#{name}" {
  group_email = gsuite_group.#{name}.email
TERRAFORM

    # Add a member block for everyone
    # downcase is used as internal G Suite representation is always lowercase
    # this avoids unnecessary state churn
    persons.each do |p|
      tf += <<-TERRAFORM
  member {
    email = "#{p.email.downcase}"
    role = "MEMBER"
  }
TERRAFORM
    end

    tf += "\n}"
    tf
  end
end
