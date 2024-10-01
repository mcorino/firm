# FIRM::Serializer - shape serializer module
# Copyright (c) M.J.N. Corino, The Netherlands


require 'yaml'
require 'date'
require 'set'
# from Ruby 3.5.0 OpenStruct will not be available by default anymore
begin
  require 'ostruct'
rescue LoadError
end

module FIRM

  module Serializable

    module YAML

      class << self
        def serializables
          list = [::Date, ::DateTime, ::Range, ::Rational, ::Complex, ::Regexp, ::Struct, ::Symbol, ::Time, ::Set]
          list.push(::OpenStruct) if ::Object.const_defined?(:OpenStruct)
          list.push(::BigDecimal) if ::Object.const_defined?(:BigDecimal)
          list
        end
      end

      module YamlSerializePatch

        ALLOWED_ALIASES = [Serializable::ID]

        if ::RUBY_VERSION >= '3.1.0'
          def revive(klass, node)
            if FIRM::Serializable > klass
              s = register(node, klass.allocate)
              s.__send__(:init_from_serialized, data = revive_hash({}, node, true))
              init_with(s, data, node)
            else
              super
            end
          end
        else
          def revive(klass, node)
            if FIRM::Serializable > klass
              s = register(node, klass.allocate)
              s.__send__(:init_from_serialized, data = revive_hash({}, node))
              init_with(s, data, node)
            else
              super
            end
          end
        end
      end

      class RestrictedRelaxed < ::YAML::ClassLoader
        def initialize(classes)
          @classes = classes
          @allow_struct = @classes.include?('Struct')
          super()
        end

        private

        def find(klassname)
          if @classes.include?(klassname)
            super
          elsif @allow_struct && ::Struct > super
            @cache[klassname]
          else
            raise ::YAML::DisallowedClass.new('load', klassname)
          end
        end
      end

      # Derived Psych YAMLTree class to emit simple strings for
      # Class instances
      class NoClassYAMLTree < ::Psych::Visitors::YAMLTree

        def visit_Class(o)
          raise TypeError, "can't dump anonymous module: #{o}" unless o.name
          visit_String(o.name)
        end

        def visit_Module(o)
          raise TypeError, "can't dump anonymous class: #{o}" unless o.name
          visit_String(o.name)
        end

      end

      def self.dump(obj, io=nil, **)
        visitor = YAML::NoClassYAMLTree.create
        visitor << obj
        visitor.tree.yaml io
      end

      def self.load(source)
        result = ::YAML.parse(source, filename: nil)
        return nil unless result
        allowed_classes =(YAML.serializables + Serializable.serializables.to_a).map(&:to_s)
        class_loader = RestrictedRelaxed.new(allowed_classes)
        scanner      = ::YAML::ScalarScanner.new(class_loader)
        visitor = ::YAML::Visitors::ToRuby.new(scanner, class_loader)
        visitor.extend(YamlSerializePatch)
        visitor.accept result
      end

    end

    # extend instance serialization methods
    module SerializeInstanceMethods

      def encode_with(coder)
        for_serialize(coder)
      end

      def init_with(coder)
        from_serialized(coder.map)
        finalize_from_serialized
      end

    end

    class ID

      def encode_with(coder)
        for_serialize(coder)
      end

      def init_with(_coder)
        # noop
      end

    end

    register(:yaml, YAML)

  end

end
