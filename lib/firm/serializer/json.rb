# FIRM::Serializer - shape serializer module
# Copyright (c) M.J.N. Corino, The Netherlands


require 'json'
require 'json/add/date'
require 'json/add/date_time'
require 'json/add/range'
require 'json/add/regexp'
require 'json/add/struct'
require 'json/add/symbol'
require 'json/add/time'
require 'json/add/bigdecimal' if ::Object.const_defined?(:BigDecimal)
require 'json/add/rational'
require 'json/add/complex'
require 'json/add/set'
# from Ruby 3.5.0 OpenStruct will not be available by default anymore
begin
  require 'ostruct'
  require 'json/add/ostruct'
rescue LoadError
end

module FIRM

  module Serializable

    module JSON

      CREATE_ID = 'rbklass'.freeze

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

      module ContainerPatch

        def self.included(base)
          class << base
            def json_new(object, &block)
              # deserializing (anchor) object or alias
              if object.has_key?('*id')
                if FIRM::Serializable::Aliasing.restored?(self, object['*id'])
                  # resolving an already restored anchor for this alias
                  FIRM::Serializable::Aliasing.resolve_anchor(self, object['*id'])
                else
                  # in case of cyclic references JSON will restore aliases before the anchors
                  # so in this case we instantiate an instance here and register it as
                  # the anchor; when the anchor is restored it will replace the contents of this
                  # instance with the restored elements
                  FIRM::Serializable::Aliasing.restore_anchor(object['*id'], self.new)
                end
              else
                instance = if object.has_key?('&id')
                             anchor_id = object['&id'] # extract anchor id
                             if FIRM::Serializable::Aliasing.restored?(self, anchor_id)
                               # in case of cyclic references an alias will already have restored the anchor instance
                               # (default constructed); retrieve that instance here for deserialization of properties
                               FIRM::Serializable::Aliasing.resolve_anchor(self, anchor_id)
                             else
                               # restore the anchor here with a newly instantiated instance
                               FIRM::Serializable::Aliasing.restore_anchor(anchor_id, self.new)
                             end
                           else
                             self.new
                           end
                block.call(instance)
                instance
              end
            end
            private :json_new
          end
        end

        def build_json(&block)
          json_data = {
            ::JSON.create_id => self.class.name
          }
          if (anchor = FIRM::Serializable::Aliasing.get_anchor(self))
            anchor_data = FIRM::Serializable::Aliasing.get_anchor_data(self)
            # retroactively insert the anchor in the anchored instance's serialization data
            anchor_data['&id'] = anchor unless anchor_data.has_key?('&id')
            json_data['*id'] = anchor
          else
            # register anchor object **before** serializing properties to properly handle cycling (bidirectional
            # references)
            FIRM::Serializable::Aliasing.register_anchor_object(self, json_data)
            block.call(json_data)
          end
          json_data
        end
        private :build_json

      end

      class << self
        def serializables
          set = ::Set.new( [::NilClass, ::TrueClass, ::FalseClass, ::Integer, ::Float, ::String, ::Array, ::Hash,
                     ::Date, ::DateTime, ::Range, ::Rational, ::Complex, ::Regexp, ::Struct, ::Symbol, ::Time, ::Set])
          set << ::OpenStruct if ::Object.const_defined?(:OpenStruct)
          set << ::BigDecimal if ::Object.const_defined?(:BigDecimal)
          set
        end

        TLS_SAFE_DESERIALIZE_KEY = :firm_json_safe_deserialize.freeze
        private_constant :TLS_SAFE_DESERIALIZE_KEY

        TLS_PARSE_STACK_KEY = :firm_json_parse_stack.freeze
        private_constant :TLS_PARSE_STACK_KEY

        def safe_deserialize
          Serializable.tls_vars[TLS_SAFE_DESERIALIZE_KEY] ||= []
        end
        private :safe_deserialize

        def start_safe_deserialize
          safe_deserialize.push(true)
        end

        def end_safe_deserialize
          safe_deserialize.pop
        end

        def parse_stack
          Serializable.tls_vars[TLS_PARSE_STACK_KEY] ||= []
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
        # obj.extend(HashInstancePatch) if obj.is_a?(::Hash)
        begin
          # initialize anchor registry
          Serializable::Aliasing.start_anchor_object_registry
          # set custom (more compact) create_id
          ::JSON.create_id = Serializable::JSON::CREATE_ID
          for_json = obj.respond_to?(:as_json) ? obj.as_json : obj
          if pretty
            if io || io.respond_to?(:write)
              io.write(::JSON.pretty_generate(for_json))
              io
            else
              ::JSON.pretty_generate(for_json)
            end
          else
            ::JSON.dump(for_json, io)
          end
        ensure
          # reset anchor registry
          Serializable::Aliasing.clear_anchor_object_registry
        end
      end

      def self.load(source)
        begin
          # initialize alias anchor restoration map
          Serializable::Aliasing.start_anchor_references
          # enable safe deserializing
          self.start_safe_deserialize
          # set custom (more compact) create_id
          ::JSON.create_id = Serializable::JSON::CREATE_ID
          ::JSON.parse!(source,
                        create_additions: true,
                        object_class: Serializable::JSON::ObjectHash)
        ensure
          # reset safe deserializing
          self.end_safe_deserialize
          # reset alias anchor restoration map
          Serializable::Aliasing.clear_anchor_references
        end
      end


      # extend serialization class methods
      module SerializeClassMethods

        def json_create(object)
          data = object['data']
          # deserializing (anchor) object or alias
          if object.has_key?('*id')
            if Serializable::Aliasing.restored?(self, object['*id'])
              # resolving an already restored anchor for this alias
              Serializable::Aliasing.resolve_anchor(self, object['*id'])
            else
              # in case of cyclic references JSON will restore aliases before the anchors
              # so in this case we allocate an instance here and register it as
              # the anchor; when the anchor is restored it will re-use this instance to initialize & restore
              # the properties
              Serializable::Aliasing.restore_anchor(object['*id'], self.allocate)
            end
          else
            instance = if object.has_key?('&id')
                         anchor_id = object['&id'] # extract anchor id
                         if Serializable::Aliasing.restored?(self, anchor_id)
                           # in case of cyclic references an alias will already have restored the anchor instance
                           # (default constructed); retrieve that instance here for deserialization of properties
                           Serializable::Aliasing.resolve_anchor(self, anchor_id)
                         else
                           # restore the anchor here with a newly allocated instance
                           Serializable::Aliasing.restore_anchor(anchor_id, self.allocate)
                         end
                       else
                         self.allocate
                       end
            instance.__send__(:init_from_serialized, data)
                    .__send__(:from_serialized, data)
                    .__send__(:finalize_from_serialized)
          end
        end

      end

      # extend instance serialization methods
      module SerializeInstanceMethods

        def as_json(*)
          json_data = {
            ::JSON.create_id => self.class.name
          }
          if (anchor = Serializable::Aliasing.get_anchor(self))
            anchor_data = Serializable::Aliasing.get_anchor_data(self)
            # retroactively insert the anchor in the anchored instance's serialization data
            anchor_data['&id'] = anchor unless anchor_data.has_key?('&id')
            json_data['*id'] = anchor
          else
            # register anchor object **before** serializing properties to properly handle cycling (bidirectional
            # references)
            Serializable::Aliasing.register_anchor_object(self, json_data)
            data = for_serialize({})
            unless data.empty?
              json_data['data'] = data
              json_data['data'].transform_values! { |v| v.respond_to?(:as_json) ? v.as_json : v }
            end
          end
          json_data
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

      include JSON::SerializeClassMethods

    end

    # extend instance serialization methods
    module SerializeInstanceMethods

      include JSON::SerializeInstanceMethods

    end

    class ID
      include JSON::SerializeInstanceMethods
      class << self
        include JSON::SerializeClassMethods
      end
    end

    register(:json, JSON)

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

class ::Array
  include FIRM::Serializable::JSON::ContainerPatch

  class << self
    # Create a new Array instance from deserialized JSON data.
    # @param [Hash] object deserialized JSON object
    # @return [Array] restored Array instance
    def json_create(object)
      json_new(object) { |instance| instance.replace(object['data']) }
    end
  end

  def as_json(*)
    build_json do |json_data|
      json_data['data'] = collect { |e| e.respond_to?(:as_json) ? e.as_json : e }
    end
  end
end

class ::Hash
  include FIRM::Serializable::JSON::ContainerPatch

  class << self
    # Create a new Hash instance from deserialized JSON data.
    # @param [Hash] object deserialized JSON object
    # @return [Hash] restored Hash instance
    def json_create(object)
      json_new(object) { |instance| instance.replace(object['data'].to_h) }
    end
  end

  def as_json(*)
    build_json do |json_data|
      json_data['data'] = collect { |k,v| [k.respond_to?(:as_json) ? k.as_json : k, v.respond_to?(:as_json) ? v.as_json : v] }
    end
  end
end

class ::Set
  include FIRM::Serializable::JSON::ContainerPatch

  class << self
    # Create a new Set instance from deserialized JSON data.
    # @param [Hash] object deserialized JSON object
    # @return [Set] restored Set instance
    def json_create(object)
      json_new(object) { |instance| instance.replace(object['a']) }
    end
  end

  def as_json(*)
    build_json do |json_data|
      json_data['a'] = to_a.collect { |e| e.respond_to?(:as_json) ? e.as_json : e }
    end
  end
end

class ::Struct
  include FIRM::Serializable::JSON::ContainerPatch

  class << self
    # Create a new Struct instance from deserialized JSON data.
    # @param [Hash] object deserialized JSON object
    # @return [Struct] restored Set instance
    def json_create(object)
        json_new(object) do |instance|
          values = object['v']
          instance.members.each_with_index { |n, i| instance[n] = values[i] }
        end
    end
  end

  def as_json(*)
    self.class.name.to_s.empty? and raise JSON::JSONError, "Only named structs are supported!"
    build_json do |json_data|
      json_data['v'] = values.collect { |e| e.respond_to?(:as_json) ? e.as_json : e }
    end
  end
end

if ::Object.const_defined?(:OpenStruct)
  class ::OpenStruct
    include FIRM::Serializable::JSON::ContainerPatch

    class << self
      # Create a new OpenStruct instance from deserialized JSON data.
      # @param [Hash] object deserialized JSON object
      # @return [OpenStruct] restored OpenStruct instance
      def json_create(object)
          json_new(object) { |instance| object['t'].each { |k,v| instance[k] = v } }
      end
    end

    def as_json(*)
      build_json do |json_data|
        json_data['t'] = table.collect { |k,v| [k.respond_to?(:as_json) ? k.as_json : k, v.respond_to?(:as_json) ? v.as_json : v] }
      end
    end
  end
end

# fix flawed JSON serializing
class ::DateTime

  def as_json(*)
    {
      JSON.create_id => self.class.name,
      'y' => year,
      'm' => month,
      'd' => day,
      'H' => hour,
      'M' => min,
      'S' => sec_fraction.to_f+sec,
      'of' => offset.to_s,
      'sg' => start,
    }
  end

end
