require 'rspec/expectations'
require_relative '../spec_helper.rb'

RSpec::Matchers.define :be_a_valid_uuid do
  match do |uuid_string|
    RubyCqrs::Guid.validate? uuid_string
  end
end
