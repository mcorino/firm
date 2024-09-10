# FIRM::Serializer - Ruby core serializer extensions
# Copyright (c) M.J.N. Corino, The Netherlands

# we do not include FIRM::Serializer::SerializeMethod here as that would
# also extend these classes with the engine specific extension that we do not
# need nor want here
# Instead we define a slim mixin module to extend (complex) core classes

module FIRM
  module Serializable
    module CoreExt
      def serialize(io = nil, pretty: false, format: FIRM::Serializable.default_format)
        FIRM::Serializable[format].dump(self, io, pretty: pretty)
      end

      def self.included(base)
        base.class_eval do
          # Deserializes object from source data
          # @param [IO,String] source source data (String or IO(-like object))
          # @param [Symbol, String] format data format of source
          # @return [Object] deserialized object
          def self.deserialize(source, format: Serializable.default_format)
            Serializable.deserialize(source, format: format)
          end
        end
      end
    end
  end
end

require 'set'
require 'ostruct'

[::Array, ::Hash, ::Struct, ::Range, ::Rational, ::Complex, ::Regexp, ::Set, ::OpenStruct, ::Time, ::Date, ::DateTime].each do |c|
  c.include FIRM::Serializable::CoreExt
end

if ::Object.const_defined?(:BigDecimal)
  ::BigDecimal.include FIRM::Serializable::CoreExt
end
