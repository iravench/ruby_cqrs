module RubyCqrs
  class NotADomainSnapshotError < Error; end

  module Domain
    module Snapshot
      include RubyCqrs::Data::Encodable
    end
  end
end
