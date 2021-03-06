require 'uuidtools'

module RubyCqrs
  class Guid
    def self.create
      UUIDTools::UUID.timestamp_create.to_s
    end

    def self.validate?(guid)
      UUIDTools::UUID.parse(guid).valid?
    end
  end
end
