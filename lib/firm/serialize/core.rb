# FIRM::Serializer - Ruby core serializer extensions
# Copyright (c) M.J.N. Corino, The Netherlands


module FIRM
  module Serializable

    # FIRM::Serializable is not included for the Ruby core classes as the would
    # also extend these classes with the engine specific extension that we do not
    # need nor want here.
    # Instead we define the (slim) mixin module CoreExt to extend the non-POD core classes.
    # POD classes (nil, boolean, integer, float) cannot be serialized separately but only
    # as properties of complex serializables.
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
# from Ruby 3.5.0 OpenStruct will not be available by default anymore
begin
  require 'ostruct'
rescue LoadError
end

[::Array, ::Hash, ::Struct, ::Range, ::Rational, ::Complex, ::Regexp, ::Set, ::Time, ::Date, ::DateTime].each do |c|
  c.include FIRM::Serializable::CoreExt
end

if ::Object.const_defined?(:OpenStruct)
  ::OpenStruct.include FIRM::Serializable::CoreExt
end

if ::Object.const_defined?(:BigDecimal)
  ::BigDecimal.include FIRM::Serializable::CoreExt
end
