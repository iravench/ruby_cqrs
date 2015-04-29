module RubyCqrs
  class NotADomainSnapshotError < StandardError; end

  module Domain
    module Snapshot
      include RubyCqrs::Data::Encodable
    end
  end
end
