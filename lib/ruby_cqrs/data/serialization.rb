require 'active_support/inflector'
require 'beefcake'

module RubyCqrs
  module Data
    module Encodable

      def try_encode
        return self.encode.to_s if self.is_a? Beefcake::Message
        self
      end
    end
  end
end

module RubyCqrs
  module Data
    module Decodable

      def try_decode type_str, data
        obj_type = type_str.constantize
        return data unless obj_type.include? Beefcake::Message
        obj_type.decode data
      end
    end
  end
end
