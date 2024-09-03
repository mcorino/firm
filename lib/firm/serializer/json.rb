# FIRM::Serializer - shape serializer module
# Copyright (c) M.J.N. Corino, The Netherlands

require 'json'
require 'json/add/core'
require 'json/add/set'
require 'json/add/ostruct'

module FIRM

  module Serializable

    module JSON

      # Derived Hash class to use for deserialized JSON object data which
      # supports using Symbol keys.
      class ObjectHash < ::Hash
        # Returns the object associated with given key.
        # @param [String,Symbol] key key value
        # @return [Object] associated object
        # @see ::Hash#[]
        def [](key)
          super(key.to_s)
        end
        # Returns true if the given key exists in self otherwise false.
        # @param [String,Symbol] key key value
        # @return [Boolean]
        # @see ::Hash#include?
        def include?(key)
          super(key.to_s)
        end
        alias member? include?
        alias has_key? include?
        alias key? include?
      end

      # Mixin module to patch hash objects during JSON serialization.
      # By default JSON will not consider hash keys for custom serialization
      # but assumes any key should be serialized as it's string representation.
      # This is restrictive but compatible with "pure" JSON object notation.
      # JSON however also does not (correctly?) honour overriding Hash#to_json to
      # customize serialization of Hash-es which seems too restrictive (stupid?)
      # as using more complex custom keys for Hash-es instead of String/Symbol-s
      # is not that uncommon.
      # This mixin is used to "patch" Hash **instances** through #extend.
      module HashInstancePatch
        def patch_nested_hashes(obj)
          case obj
          when ::Hash
            obj.extend(HashInstancePatch) unless obj.singleton_class.include?(HashInstancePatch)
            obj.each_pair { |k, v| patch_nested_hashes(k); patch_nested_hashes(v) }
          when ::Array
            obj.each { |e| patch_nested_hashes(e) }
          end
          obj
        end
        private :patch_nested_hashes

        # Returns JSON representation (String) of self.
        # Hash data which is part of object properties/members being serialized
        # (including any nested Hash-es) will be patched with HashInstancePatch.
        # Patched Hash instances will be serialized as JSON-creatable objects
        # (so provided with a JSON#create_id) with the hash contents represented
        # as an array of key/value pairs (arrays).
        # @param [Array<Object>] args any args passed by the JSON generator
        # @return [String] JSON representation
        def to_json(*args)
          if self.has_key?(::JSON.create_id)
            if self.has_key?('data')
              if (data = self['data']).is_a?(::Hash)
                data.each_value { |v| patch_nested_hashes(v) }
              end
            else # core class extensions use different data members for property serialization
              self.each_value { |v| patch_nested_hashes(v) }
            end
            super
          else
            {
              ::JSON.create_id => self.class.name,
              'data' => patch_nested_hashes(to_a)
            }.to_json(*args)
          end
        end
      end

      # Mixin module to patch singleton_clas of the Hash class to make Hash-es
      # JSON creatable (#json_creatable? returns true).
      module HashClassPatch
        # Create a new Hash instance from deserialized JSON data.
        # @param [Hash] object deserialized JSON object
        # @return [Hash] restored Hash instance
        def json_create(object)
          object['data'].to_h
        end
      end

      class ::Hash
        include FIRM::Serializable::JSON::HashInstancePatch
        class << self
          include FIRM::Serializable::JSON::HashClassPatch
        end
      end

      class << self
        def serializables
          ::Set.new [::NilClass, ::TrueClass, ::FalseClass, ::Integer, ::Float, ::String, ::Array, ::Hash,
                     ::Date, ::DateTime, ::Exception, ::Range, ::Regexp, ::Struct, ::Symbol, ::Time, ::Set, ::OpenStruct]
        end

        TLS_SAFE_DESERIALIZE_KEY = :firm_json_safe_deserialize.freeze
        private_constant :TLS_SAFE_DESERIALIZE_KEY

        TLS_PARSE_STACK_KEY = :firm_json_parse_stack.freeze
        private_constant :TLS_PARSE_STACK_KEY

        def safe_deserialize
          ::Thread.current[TLS_SAFE_DESERIALIZE_KEY] ||= []
        end
        private :safe_deserialize

        def start_safe_deserialize
          safe_deserialize.push(true)
        end

        def end_safe_deserialize
          safe_deserialize.pop
        end

        def parse_stack
          ::Thread.current[TLS_PARSE_STACK_KEY] ||= []
        end
        private :parse_stack

        def start_parse
          parse_stack.push(safe_deserialize.pop)
        end

        def end_parse
          unless (val = parse_stack.pop).nil?
            safe_deserialize.push(val)
          end
        end

        def safe_parsing?
          !!parse_stack.last
        end
      end

      def self.dump(obj, io=nil, pretty: false)
        obj.extend(HashInstancePatch) if obj.is_a?(::Hash)
        begin
          # initialize anchor registry
          Serializable::Aliasing.start_anchor_registry
          if pretty
            if io || io.respond_to?(:write)
              io.write(::JSON.pretty_generate(obj))
              io
            else
              ::JSON.pretty_generate(obj)
            end
          else
            ::JSON.dump(obj, io)
          end
        ensure
          # reset anchor registry
          Serializable::Aliasing.clear_anchor_registry
        end
      end

      def self.load(source)
        begin
          # initialize ID restoration map
          Serializable::ID.init_restoration_map
          # initialize alias anchor restoration map
          Serializable::Aliasing.start_anchor_references
          # enable safe deserializing
          self.start_safe_deserialize
          ::JSON.parse!(source,
                        **{create_additions: true,
                           object_class: Serializable::JSON::ObjectHash})
        ensure
          # reset safe deserializing
          self.end_safe_deserialize
          # reset alias anchor restoration map
          Serializable::Aliasing.clear_anchor_references
          # reset ID restoration map
          Serializable::ID.clear_restoration_map
        end
      end

    end

    module Aliasing
      class << self
        include Serializable::AliasManagement
      end
    end

    # extend serialization class methods
    module SerializeClassMethods

      def json_create(object)
        if self.allows_aliases?
          # deserializing anchor or alias
          if object['data'].has_key?('&id')
            anchor_id = object['data'].delete('&id')
            instance = create_for_deserialize(data = object['data'])
                         .__send__(:from_serialized, data)
                         .__send__(:finalize_from_serialized)
            Serializable::Aliasing.restore_anchor(anchor_id, instance)
          elsif object['data'].has_key?('*id')
            Serializable::Aliasing.resolve_anchor(self, object['data']['*id'])
          else
            raise RuntimeError, 'Aliasable instance misses anchor or alias id'
          end
        else
          create_for_deserialize(data = object['data'])
            .__send__(:from_serialized, data)
            .__send__(:finalize_from_serialized)
        end
      end

    end

    # extend instance serialization methods
    module SerializeInstanceMethods

      def to_json(*args)
        json_data = {
          ::JSON.create_id => self.class.name
        }
        if self.class.allows_aliases? && Serializable::Aliasing.anchored?(self)
          json_data["data"] = {
            '*id' => Serializable::Aliasing.get_anchor(self)
          }
        else
          json_data['data'] = for_serialize(Hash.new)
          json_data['data']['&id'] = Serializable::Aliasing.create_anchor(self) if self.class.allows_aliases?
        end
        json_data.to_json(*args)
      end

    end

    class ID

      def self.json_create(object)
        # does not need calls to #from_serialized or #finalize_from_serialized
        create_for_deserialize(data = object['data'])
      end

      def to_json(*args)
        {
          ::JSON.create_id => self.class.name,
          'data' => for_serialize(Hash.new)
        }.to_json(*args)
      end

    end

    register(Serializable.default_format, JSON)

  end

end

module ::JSON
  class << self

    alias :pre_firm_parse! :parse!
    def parse!(*args, **kwargs)
      begin
        # setup parsing stack for safe or normal deserializing
        # the double bracketing provided from FIRM::Serializable::JSON#load and here
        # makes sure to support both nested Wx::SF deserializing as well as nested
        # hybrid deserializing (Wx::SF -> common JSON -> ...)
        FIRM::Serializable::JSON.start_parse
        pre_firm_parse!(*args, **kwargs)
      ensure
        # reset parsing stack
        FIRM::Serializable::JSON.end_parse
      end
    end

  end
end

class ::Class

  # override this to be able to do safe deserializing
  def json_creatable?
    if FIRM::Serializable::JSON.safe_parsing?
      return false unless FIRM::Serializable::JSON.serializables.include?(self) ||
                          FIRM::Serializable.serializables.include?(self) ||
                          ::Struct > self
    end
    respond_to?(:json_create)
  end

end
