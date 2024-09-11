# FIRM::Serializable - serializable mixin
# Copyright (c) M.J.N. Corino, The Netherlands

require 'set'

module FIRM

  module Serializable

    class Exception < RuntimeError; end

    class Property
      def initialize(klass, prop, proc=nil, force: false, handler: nil, &block)
        ::Kernel.raise ArgumentError, "Invalid property id [#{prop}]" unless ::String === prop || ::Symbol === prop
        ::Kernel.raise ArgumentError, "Duplicate property id [#{prop}]" if klass.has_serializer_property?(prop)
        @klass = klass
        @id = prop.to_sym
        @forced = force
        if block || handler
          if handler
            ::Kernel.raise ArgumentError,
                           "Invalid property handler #{handler} for #{prop}" unless ::Proc === handler || ::Symbol === handler
            if handler.is_a?(::Proc)
              ::Kernel.raise ArgumentError, "Invalid property block #{proc} for #{prop}" unless block.arity == -3
              @getter = ->(obj) { handler.call(@id, obj) }
              @setter = ->(obj, val) { handler.call(@id, obj, val) }
            else
              @getter = ->(obj) { obj.send(handler, @id) }
              @setter = ->(obj, val) { obj.send(handler, @id, val) }
            end
          else
            # any property block MUST accept 2 or 3 args; property name, instance and value (for setter)
            ::Kernel.raise ArgumentError, "Invalid property block #{proc} for #{prop}" unless block.arity == -3
            @getter = ->(obj) { block.call(@id, obj) }
            @setter = ->(obj, val) { block.call(@id, obj, val) }
          end
        elsif proc
          ::Kernel.raise ArgumentError,
                         "Invalid property proc #{proc} for #{prop}" unless ::Proc === proc || ::Symbol === proc
          if ::Proc === proc
            # any property proc should be callable with a single arg (instance)
            @getter = proc
            # a property proc combining getter/setter functionality should accept a single or more args (instance + value)
            @setter = (proc.arity == -2) ? proc : nil
          else
            @getter = ->(obj) { obj.send(proc) }
            @setter = ->(obj, val) { obj.send(proc, val) }
          end
        end
      end

      attr_reader :id

      def serialize(obj, data, excludes)
        unless excludes.include?(@id)
          val = getter.call(obj)
          unless Serializable === val && val.serialize_disabled? && !@forced
            data[@id] = case val
                        when ::Array
                          val.select { |elem| !(Serializable === elem && elem.serialize_disabled?) }
                        when ::Set
                          ::Set.new(val.select { |elem| !(Serializable === elem && elem.serialize_disabled?) })
                        else
                          val
                        end
          end
        end
      end

      def deserialize(obj, data)
        if data.has_key?(@id)
          setter.call(obj, data[@id])
        end
      end

      def get(obj)
        getter.call(obj)
      end

      def get_method(id)
        begin
          @klass.instance_method(id)
        rescue NameError
          nil
        end
      end
      private :get_method

      def getter
        unless @getter
          inst_meth = get_method(@id)
          inst_meth = get_method("get_#{@id}") unless inst_meth
          if inst_meth
            @getter = ->(obj) { inst_meth.bind(obj).call }
          else
            return self.method(:getter_fail)
          end
        end
        @getter
      end
      private :getter

      def setter
        unless @setter
          inst_meth = get_method("#{@id}=")
          inst_meth = get_method("set_#{@id}") unless inst_meth
          unless inst_meth
            im = get_method(@id)
            if im && im.arity == -1
              inst_meth = im
            else
              inst_meth = nil
            end
          end
          if inst_meth
            @setter = ->(obj, val) { inst_meth.bind(obj).call(val) }
          else
            return self.method(:setter_noop)
          end
        end
        @setter
      end
      private :setter

      def getter_fail(_obj)
        ::Kernel.raise Serializable::Exception, "Missing getter for property #{@id} of #{@klass}"
      end
      private :getter_fail

      def setter_noop(_, _)
        # do nothing
      end
      private :setter_noop
    end

    # Serializable unique ids.
    # This class makes sure to maintain uniqueness across serialization/deserialization cycles
    # and keeps all shared instances within a single (serialized/deserialized) object set in
    # sync.
    class ID; end

    class << self

      def serializables
        @serializables ||= ::Set.new
      end

      def formatters
        @formatters ||= {}
      end
      private :formatters

      # Registers a serialization formatting engine
      # @param [Symbol,String] format format id
      # @param [Object] engine formatting engine
      def register(format, engine)
        if formatters.has_key?(format.to_s.downcase)
          ::Kernel.raise ArgumentError,
                         "Duplicate serialization formatter registration for #{format}"
        end
        formatters[format.to_s.downcase] = engine
      end

      # Return a serialization formatting engine
      # @param [Symbol,String] format format id
      # @return [Object] formatting engine
      def [](format)
        formatters[format.to_s.downcase]
      end

      # Return the default output format symbol id (:json, :yaml, :xml).
      # By default returns :json.
      # @return [Symbol]
      def default_format
        @default_format ||= :json
      end

      # Set the default output format.
      # @param [Symbol] format Output format id. By default :json, :yaml and :xml (if nokogiri gem is installed) are supported.
      # @return [Symbol] default format
      def default_format=(format)
        @default_format = format
      end

    end

    # This module provides the base support for instance aliasing and is
    # used as a mixin for classes for which aliases have been allowed.
    module Aliasing

      class << self

        # Returns a {Set} of classes for which aliases are allowed.
        # @return [::Set]
        def aliasable_classes
          @aliasable_classes ||= ::Set.new
        end

        # Returns true if the given class allows aliasing, false otherwise.
        # @return [Boolean]
        def allows_aliases?(klass)
          aliasable_classes.include?(klass)
        end

      end

      def self.included(base)
        # only once
        return if Serializable::Aliasing.allows_aliases?(base)
        # register this class as an aliasable class
        Serializable::Aliasing.aliasable_classes << base
        # to optimize testing for allowable aliases
        base.singleton_class.class_eval do
          def allows_aliases?
            true
          end
        end
      end

    end

    # This module provides alias (de-)serialization management functionality for
    # output engines that do not provide this support out of the box.
    module AliasManagement

      TLS_ANCHORS_STACK_KEY = :firm_alias_anchors_stack.freeze
      private_constant :TLS_ANCHORS_STACK_KEY

      TLS_ALIAS_STACK_KEY = :firm_anchor_reference_stack.freeze
      private_constant :TLS_ALIAS_STACK_KEY

      def anchor_registry_stack
        ::Thread.current[TLS_ANCHORS_STACK_KEY] ||= []
      end
      private :anchor_registry_stack

      def start_anchor_registry
        anchor_registry_stack.push({})
      end

      def clear_anchor_registry
        anchor_registry_stack.pop
      end

      def anchor_registry
        anchor_registry_stack.last
      end
      private :anchor_registry

      def class_anchors(klass)
        anchor_registry[klass] ||= {}
      end
      private :class_anchors

      # Creates a new anchor registration and returns the anchor ID
      # @param [Object] object anchor instance
      # @return [Integer] anchor ID
      def create_anchor(object)
        anchors = class_anchors(object.class)
        raise Serializable::Exception, "Duplicate anchor creation for #{object}" if anchors.has_key?(object.object_id)
        anchors[object.object_id] = object.object_id
      end

      # Returns true if the object has an anchor registration, false otherwise.
      # @return [Boolean]
      def anchored?(object)
        class_anchors(object.class).has_key?(object.object_id)
      end

      # Retrieves the anchor ID for an anchored object.
      # Returns nil if the object is not anchored.
      # @return [nil,Integer]
      def get_anchor(object)
        anchors = class_anchors(object.class)
        anchors[object.object_id]
      end

      def anchor_references_stack
        ::Thread.current[TLS_ALIAS_STACK_KEY] ||= []
      end
      private :anchor_references_stack

      def start_anchor_references
        anchor_references_stack.push({})
      end

      def clear_anchor_references
        anchor_references_stack.pop
      end

      def anchor_references
        anchor_references_stack.last
      end
      private :anchor_references

      def class_anchor_references(klass)
        anchor_references[klass] ||= {}
      end
      private :class_anchor_references

      # Registers a restored anchor object and it's ID.
      # @param [Integer] id anchor ID
      # @param [Object] object anchor instance
      # @return [Object] anchor instance
      def restore_anchor(id, object)
        class_anchor_references(object.class)[id] = object
      end

      # Resolves a referenced anchor instance.
      # Returns the instance if found, nil otherwise.
      # @param [Class] klass aliasable class of the anchor instance
      # @param [Integer] id anchor id
      # @return [nil,Object]
      def resolve_anchor(klass, id)
        class_anchor_references(klass)[id]
      end

    end

    # Mixin module for classes that get FIRM::Serializable included.
    # This module is used to extend the class methods of the serializable class.
    module SerializeClassMethods

      # Adds (a) serializable property(-ies) for instances of his class (and derived classes)
      # @overload property(*props, force: false)
      #   Specifies one or more serialized properties.
      #   The serialization framework will determine the availability of setter and getter methods
      #   automatically by looking for methods <code>"#{prop_id}=(v)"</code>, <code>"set_#{prop_id}(v)"</code> or <code>"#{prop}(v)"</code>
      #   for setters and <code>"#{prop_id}()"</code> or <code>"get_#{prop_id}"</code> for getters.
      #   @param [Symbol,String] props one or more ids of serializable properties
      #   @param [Boolean] force overrides any #disable_serialize for the properties specified
      # @overload property(hash, force: false)
      #   Specifies one or more serialized properties with associated setter/getter method ids/procs/lambda-s.
      #   @example
      #     property(
      #       prop_a: ->(obj, *val) {
      #                 obj.my_prop_a_setter(val.first) unless val.empty?
      #                 obj.my_prop_a_getter
      #               },
      #       prop_b: Proc.new { |obj, *val|
      #                 obj.my_prop_b_setter(val.first) unless val.empty?
      #                 obj.my_prop_b_getter
      #               },
      #       prop_c: :serialization_method)
      #   Procs with setter support MUST accept 1 or 2 arguments (1 for getter, 2 for setter).
      #   @note Use `*val` to specify the optional value argument for setter requests instead of `val=nil`
      #         to be able to support setting explicit nil values.
      #   @param [Hash] hash a hash of pairs of property ids and getter/setter procs
      #   @param [Boolean] force overrides any #disable_serialize for the properties specified
      # @overload property(*props, force: false, handler: nil, &block)
      #   Specifies one or more serialized properties with a getter/setter handler proc/method/block.
      #   The getter/setter proc or block should accept either 2 (property id and object for getter) or 3 arguments
      #   (property id, object and value for setter) and is assumed to handle getter/setter requests
      #   for all specified properties.
      #   The getter/setter method should accept either 1 (property id for getter) or 2 arguments
      #   (property id and value for setter) and is assumed to handle getter/setter requests
      #   for all specified properties.
      #   @example
      #     property(:property_a, :property_b, :property_c) do |id, obj, *val|
      #       case id
      #         when :property_a
      #           ...
      #         when :property_b
      #           ...
      #         when :property_c
      #           ...
      #       end
      #     end
      #   @note Use `*val` to specify the optional value argument for setter requests instead of `val=nil`
      #         to be able to support setting explicit nil values.
      #   @param [Symbol,String] props one or more ids of serializable properties
      #   @param [Boolean] force overrides any #disable_serialize for the properties specified
      #   @yieldparam [Symbol,String] id property id
      #   @yieldparam [Object] obj object instance
      #   @yieldparam [Object] val optional property value to set in case of setter request
      def property(*props, **kwargs, &block)
        forced = !!kwargs.delete(:force)
        if block || kwargs[:handler]
          props.each do |prop|
            serializer_properties << Property.new(self, prop, force: forced, handler: kwargs[:handler], &block)
          end
        else
          props.flatten.each do |prop|
            if ::Hash === prop
              prop.each_pair do |pn, pp|
                serializer_properties << Property.new(self, pn, pp, force: forced)
              end
            else
              serializer_properties << Property.new(self, prop, force: forced)
            end
          end
          unless kwargs.empty?
            kwargs.each_pair do |pn, pp|
              serializer_properties << Property.new(self, pn, pp, force: forced)
            end
          end
        end
      end
      alias :properties :property
      alias :contains :property

      # Excludes a serializable property for instances of this class.
      # (mostly/only useful to exclude properties from base classes which
      # do not require serialization for derived class)
      # @param [Symbol,String] props one or more ids of serializable properties
      def excluded_property(*props)
        excluded_serializer_properties.merge props.flatten.collect { |prop| prop }
      end
      alias :excluded_properties :excluded_property
      alias :excludes :excluded_property

      # Creates a new instance for subsequent deserialization and optionally initialize
      # it using the given data hash.
      # The default implementation creates a new instance using the default constructor
      # (no arguments, no initialization) and leaves the initialization to a subsequent call
      # to the instance method #from_serialized(data).
      # Classes that do not support a default constructor can override this class method and
      # implement a custom creation scheme.
      # @param [Object] _data hash-like object containing deserialized property data (symbol keys)
      # @return [Object] the newly created object
      def create_for_deserialize(_data)
        self.new
      end

      # Defines a finalizer method/proc/block to be called after all
      def define_deserialize_finalizer(meth=nil, &block)
        self.set_deserialize_finalizer(meth, &block)
      end
      alias :deserialize_finalizer :define_deserialize_finalizer

      # Provides aliasing support for (de-)serializing
      def allow_aliases
        self.include(FIRM::Serializable::Aliasing) unless self.include?(FIRM::Serializable::Aliasing)
      end

      # Deserializes object from source data
      # @param [IO,String] source source data (String or IO(-like object))
      # @param [Symbol, String] format data format of source
      # @return [Object] deserialized object
      def deserialize(source, format: Serializable.default_format)
        Serializable.deserialize(source, format: format)
      end

    end

    # Mixin module for classes that get FIRM::Serializable included.
    # This module is used to extend the instance methods of the serializable class.
    module SerializeInstanceMethods

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

      # Returns true if regular serialization for this object has been disabled, false otherwise (default).
      # Disabled serialization can be overridden for single objects (not objects maintained in property containers
      # like arrays and sets).
      # @return [true,false]
      def serialize_disabled?
        !!@serialize_disabled # true for any value but false
      end

      # Disables serialization for this object as a single property or as part of a property container
      # (array or set).
      # @return [void]
      def disable_serialize
        # by default unset (nil) so serializing enabled
        @serialize_disabled = true
      end

      # @!method for_serialize(hash, excludes = Set.new)
      #   Serializes the properties of a serializable instance to the given hash
      #   except when the property id is included in excludes.
      #   @param [Object] hash hash-like property serialization container
      #   @param [Set] excludes set with excluded property ids
      #   @return [Object] hash-like property serialization container

      # @!method from_serialized(hash)
      #   Restores the properties of a deserialized instance.
      #   @param [Object] hash hash-like property deserialization container
      #   @return [self]

      # #!method finalize_from_serialized()
      #   Finalizes the instance initialization after property restoration.
      #   Calls any user defined finalizer.
      #   @return [self]

    end

    # Serialize the given object
    # @overload serialize(obj, pretty: false, format: Serializable.default_format)
    #   @param [Object] obj object to serialize
    #   @param [Boolean] pretty if true specifies to generate pretty formatted output if possible
    #   @param [Symbol,String] format specifies output format
    #   @return [String] serialized data
    # @overload serialize(obj, io, pretty: false, format: Serializable.default_format)
    #   @param [Object] obj object to serialize
    #   @param [IO] io output stream to write serialized data to
    #   @param [Boolean] pretty if true specifies to generate pretty formatted output if possible
    #   @param [Symbol,String] format specifies output format
    #   @return [IO]
    def self.serialize(obj, io = nil, pretty: false, format: Serializable.default_format)
      self[format].dump(obj, io, pretty: pretty)
    end

    # Deserializes object from source data
    # @param [IO,String] source source data (stream)
    # @param [Symbol, String] format data format of source
    # @return [Object] deserialized object
    def self.deserialize(source, format: Serializable.default_format)
      self[format].load(::IO === source || source.respond_to?(:read) ? source.read : source)
    end

    def self.included(base)
      ::Kernel.raise RuntimeError, "#{self} should only be included in classes" if base.instance_of?(::Module)

      ::Kernel.raise RuntimeError, "#{self} should be included only once in #{base}" if Serializable.serializables.include?(base.name)

      # register as serializable class
      Serializable.serializables << base

      return if base == Serializable::ID # special case which does not need the rest

      # provide serialized property definition support

      # provide serialized classes with their own serialized properties (exclusion) list
      # and a deserialization finalizer setter/getter
      base.singleton_class.class_eval do
        def serializer_properties
          @serializer_props ||= []
        end
        def excluded_serializer_properties
          @excluded_serializer_props ||= ::Set.new
        end
        def set_deserialize_finalizer(meth=nil, &block)
          if block and not meth
            # the given block should expect and use the given object instance
            @finalize_from_deserialized = block
          elsif meth and not block
            h_meth = case meth
                     when Symbol, String then self.instance_method(meth)
                     when Proc then meth
                     when UnboundMethod then meth
                     end
            # bind unbound method with given object instance to call
            if UnboundMethod === h_meth
              # check arity == 0
              if h_meth.arity>0
                Kernel.raise ArgumentError,
                             "Deserialize finalizer method should not expect any argument",
                             caller
              end
              @finalize_from_deserialized = ->(obj) { h_meth.bind(obj).call }
            else
              # check arity == 1
              if h_meth.arity != 1
                Kernel.raise ArgumentError,
                             "Deserialize finalizer Proc should expect a single argument",
                             caller
              end
              @finalize_from_deserialized = h_meth
            end
          else
            Kernel.raise ArgumentError,
                         "Specify deserialize finalizer with a method, name, proc OR block",
                         caller
          end
        end
        def get_deserialize_finalizer
          @finalize_from_deserialized
        end
        def allows_aliases?
          false # by default not allowed
        end
      end

      # Check if the derived class has the default deserialize finalizer method defined (a #create method
      # without arguments) defined. If so install that method as the deserialize finalizer.
      if base.method_defined?(:create, false)
        create_mtd = base.instance_method :create
        if create_mtd.arity == 0
          base.set_deserialize_finalizer(create_mtd)
        end
      end

      # add class methods
      base.extend(SerializeClassMethods)

      # add instance property (de-)serialization methods for base class
      base.class_eval <<~__CODE
        def for_serialize(hash, excludes = ::Set.new)
          #{base.name}.serializer_properties.each { |prop, h| prop.serialize(self, hash, excludes) }
          hash 
        end
        protected :for_serialize

        def from_serialized(hash)
          #{base.name}.serializer_properties.each { |prop| prop.deserialize(self, hash) }
          self
        end
        protected :from_serialized

        def finalize_from_serialized
          if (f = self.class.get_deserialize_finalizer) 
            f.call(self)
          end
          self
        end
        protected :finalize_from_serialized

        def self.has_serializer_property?(id)
          self.serializer_properties.any? { |p| p.id == id.to_sym } 
        end
      __CODE
      # add inheritance support
      base.class_eval do
        def self.inherited(derived)
          # add instance property (de-)serialization methods for derived classes
          derived.class_eval <<~__CODE
            module SerializerMethods 
              def for_serialize(hash, excludes = ::Set.new)
                hash = super(hash, excludes | #{derived.name}.excluded_serializer_properties) 
                #{derived.name}.serializer_properties.each { |prop| prop.serialize(self, hash, excludes) }
                hash 
              end
              protected :for_serialize
  
              def from_serialized(hash)
                #{derived.name}.serializer_properties.each { |prop| prop.deserialize(self, hash) }
                super(hash)
              end
              protected :from_serialized
            end
            include SerializerMethods
          __CODE
          derived.class_eval do
            def self.has_serializer_property?(id)
              self.serializer_properties.any? { |p| p.id == id.to_sym } || self.superclass.has_serializer_property?(id)
            end
          end
          # add derived class support for deserialization finalizer
          derived.singleton_class.class_eval <<~__CODE
            def get_deserialize_finalizer
              @finalize_from_deserialized || #{derived.name}.superclass.get_deserialize_finalizer 
            end
          __CODE

          # Check if the derived class has the default deserialize finalizer method defined (a #create method
          # without arguments) defined. If so install that method as the deserialize finalizer (it is expected
          # this method will call any superclass finalizer that may be defined).
          if derived.method_defined?(:create, false)
            create_mtd = derived.instance_method :create
            if create_mtd.arity == 0
              derived.set_deserialize_finalizer(create_mtd)
            end
          end

          # register as serializable class
          Serializable.serializables << derived

          # aliasing support is inherited
          if self.allows_aliases?
            Serializable::Aliasing.aliasable_classes << derived
          end
        end
      end

      # add instance serialization method
      base.include(SerializeInstanceMethods)
    end

  end # module Serializable


  # Serialize the given object
  # @overload serialize(obj, pretty: false, format: Serializable.default_format)
  #   @param [Object] obj object to serialize
  #   @param [Boolean] pretty if true specifies to generate pretty formatted output if possible
  #   @param [Symbol,String] format specifies output format
  #   @return [String] serialized data
  # @overload serialize(obj, io, pretty: false, format: Serializable.default_format)
  #   @param [Object] obj object to serialize
  #   @param [IO] io output stream (IO(-like object)) to write serialized data to
  #   @param [Boolean] pretty if true specifies to generate pretty formatted output if possible
  #   @param [Symbol,String] format specifies output format
  #   @return [IO]
  def self.serialize(obj, io = nil, pretty: false, format: Serializable.default_format)
    Serializable.serialize(obj, io, pretty: pretty, format: format)
  end

  # Deserializes object from source data
  # @param [IO,String] source source data (String or IO(-like object))
  # @param [Symbol, String] format data format of source
  # @return [Object] deserialized object
  def self.deserialize(source, format: Serializable.default_format)
    Serializable.deserialize(source, format: format)
  end

end # module FIRM

Dir[File.join(__dir__, 'serializer', '*.rb')].each { |fnm| require "firm/serializer/#{File.basename(fnm)}" }
Dir[File.join(__dir__, 'serialize', '*.rb')].each { |fnm| require "firm/serialize/#{File.basename(fnm)}" }
