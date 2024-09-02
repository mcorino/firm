# FIRM::Serializer - FIRM serializable ID class
# Copyright (c) M.J.N. Corino, The Netherlands

module FIRM

  module Serializable

    class ID

      include FIRM::Serializable

      class << self

        TLS_RESTORATION_MAP_KEY = :wx_sf_serializable_id_restoration_map.freeze
        private_constant :TLS_RESTORATION_MAP_KEY

        def init_restoration_map
          (::Thread.current[TLS_RESTORATION_MAP_KEY] ||= []) << {}
        end

        def clear_restoration_map
          ::Thread.current[TLS_RESTORATION_MAP_KEY].pop
        end

        def restoration_map
          ::Thread.current[TLS_RESTORATION_MAP_KEY].last
        end

      end

      # Returns a Serialized::Id instance matching the deserialized id number
      # either by retrieving an earlier restored Id from the (thread/fiber-)current
      # restoration map or creating (and mapping) a new Id instance.
      # @param [Hash] data deserialized properties hash
      # @return [ID] restored ID instance
      # @see SerializeClassMethods#create_for_deserialize
      def self.create_for_deserialize(data)
        serialized_id = data[:id] || 0
        restoration_map[serialized_id] ||= self.new
      end

      # Collects the ID's object_id for serialization.
      # Note that this is fixed and cannot be excluded.
      # @param [Hash] hash property serialization hash
      # @param [Set] _excludes ignored
      # @return [Hash] property serialization hash
      def for_serialize(hash, _excludes = nil)
        hash[:id] = self.object_id
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

    serializables << ID

  end

end
