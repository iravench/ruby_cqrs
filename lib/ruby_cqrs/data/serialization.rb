require 'active_support/inflector'
require 'beefcake'

module RubyCqrs
  class ObjectNotEncodableError < Error; end
  class ObjectNotDecodableError < Error; end

  module Data
    module Encodable

      def try_encode
        return self.encode.to_s if self.is_a? Beefcake::Message
        raise ObjectNotEncodableError
      end
    end

    module Decodable

      def try_decode type_str, data
        obj_type = type_str.constantize
        raise ObjectNotDecodableError unless obj_type.include? Beefcake::Message
        obj_type.decode data
      end
    end
  end
end
