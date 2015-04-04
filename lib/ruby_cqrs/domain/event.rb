module RubyCqrs
  class NotADomainEventError < Error; end

  module Domain
    module Event
      attr_reader :aggregate_id, :version
    end
  end
end
