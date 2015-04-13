module RubyCqrs
  class NotADomainEventError < Error; end

  module Domain
    module Event
      include RubyCqrs::Data::Encodable
      attr_reader :aggregate_id, :version
    end
  end
end
