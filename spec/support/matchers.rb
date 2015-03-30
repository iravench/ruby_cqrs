require 'rspec/expectations'
require 'uuidtools'

RSpec::Matchers.define :be_a_valid_uuid do
  match do |uuid_string|
    UUIDTools::UUID.parse_raw(uuid_string).valid?
  end
end
