# FIRM::Serializer - shape serializer module
# Copyright (c) M.J.N. Corino, The Netherlands

require 'yaml'
require 'set'
require 'ostruct'

module FIRM

  module Serializable

    module YAML

      class << self
        def serializables
          [Date, DateTime, Exception, Range, Regexp, Struct, Symbol, Time, Set, OpenStruct]
        end
      end

      module YamlSerializePatch

        ALLOWED_ALIASES = [Serializable::ID]

        if ::RUBY_VERSION >= '3.1.0'
          def revive(klass, node)
            if FIRM::Serializable > klass
              s = register(node, klass.create_for_deserialize(data = revive_hash({}, node, true)))
              init_with(s, data, node)
            else
              super
            end
          end
        else
          def revive(klass, node)
            if FIRM::Serializable > klass
              s = register(node, klass.create_for_deserialize(data = revive_hash({}, node)))
              init_with(s, data, node)
            else
              super
            end
          end
        end
        def visit_Psych_Nodes_Alias o
          rc = @st.fetch(o.anchor) { raise ::YAML::AnchorNotDefined, o.anchor }
          # only allow Serializable::ID aliases
          raise ::YAML::AliasesNotEnabled unless ALLOWED_ALIASES.any? { |klass| klass === rc }
          rc
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

      def self.dump(obj, io=nil, pretty: false)
        ::YAML.dump(obj, io)
      end

      def self.load(source)
        result = ::YAML.parse(source, filename: nil)
        return nil unless result
        begin
          # initialize ID restoration map
          Serializable::ID.init_restoration_map
          allowed_classes =(YAML.serializables + Serializable.serializables.to_a).map(&:to_s)
          class_loader = RestrictedRelaxed.new(allowed_classes)
          scanner      = ::YAML::ScalarScanner.new(class_loader)
          visitor = ::YAML::Visitors::NoAliasRuby.new(scanner, class_loader)
          visitor.extend(YamlSerializePatch)
          result = visitor.accept result
        ensure
          # reset ID restoration map
          Serializable::ID.clear_restoration_map
        end
        result
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
