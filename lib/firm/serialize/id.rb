# FIRM::Serializer - FIRM serializable ID class
# Copyright (c) M.J.N. Corino, The Netherlands


module FIRM

  module Serializable

    class ID

      include FIRM::Serializable

      class << self

        # Deserializes object from source data
        # @param [IO,String] source source data (String or IO(-like object))
        # @param [Symbol, String] format data format of source
        # @return [Object] deserialized object
        def deserialize(source, format: Serializable.default_format)
          Serializable.deserialize(source, format: format)
        end

      end

      # Serialize this object
      # @overload serialize(pretty: false, format: Serializable.default_format)
      #   @param [Boolean] pretty if true specifies to generate pretty formatted output if possible
      #   @param [Symbol,String] format specifies output format
      #   @return [String] serialized data
      # @overload serialize(io, pretty: false, format: Serializable.default_format)
      #   @param [IO] io output stream to write serialized data to
      #   @param [Boolean] pretty if true specifies to generate pretty formatted output if possible
      #   @param [Symbol,String] format specifies output format
      #   @return [IO]
      def serialize(io = nil, pretty: false, format: Serializable.default_format)
        Serializable[format].dump(self, io, pretty: pretty)
      end

      # Initializes a newly allocated instance for subsequent deserialization (optionally initializing
      # using the given data hash).
      # The default implementation calls the standard #initialize method without arguments (default constructor)
      # and leaves the property restoration to a subsequent call to the instance method #from_serialized(data).
      # Classes that do not support a default constructor can override this class method and
      # implement a custom initialization scheme.
      # @param [Object] _data hash-like object containing deserialized property data (symbol keys)
      # @return [Object] the initialized object
      def init_from_serialized(_data)
        initialize
        self
      end
      protected :init_from_serialized

      # Noop for ID instances.
      # @param [Object] hash hash-like property serialization container
      # @param [Set] _excludes ignored
      # @return [Object] property hash-like serialization container
      def for_serialize(hash, _excludes = nil)
        hash
      end

      protected :for_serialize

      # Noop for ID instances.
      # @param [Hash] _hash ignored
      # @return [self]
      def from_serialized(_hash)
        # no deserializing necessary
        self
      end

      protected :from_serialized

      # Noop for ID instances.
      # @return [self]
      def finalize_from_serialized
        # no finalization necessary
        self
      end

      protected :finalize_from_serialized

      # Always returns false for IDs.
      # @return [Boolean]
      def serialize_disabled?
        false
      end

      def to_s
        "FIRM::Serializable::ID<#{object_id}>"
      end

      def inspect
        to_s
      end

      def to_i
        object_id
      end

    end

  end

end
