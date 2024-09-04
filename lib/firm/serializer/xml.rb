# FIRM::Serializer - shape serializer module
# Copyright (c) M.J.N. Corino, The Netherlands

begin
  require 'nokogiri'
rescue LoadError
  # noop
end

module FIRM

  module Serializable

    module XML

      class << self

        TLS_STATE_KEY = :firm_xml_state.freeze
        private_constant :TLS_STATE_KEY

        def xml_state
          ::Thread.current[TLS_STATE_KEY] ||= []
        end
        private :xml_state

        def init_xml_load_state
          xml_state.push({
                           allowed_classes: ::Set.new(Serializable.serializables.to_a.map(&:to_s))
                         })
        end

        def clear_xml_load_state
          xml_state.pop
        end

        def xml_tag_allowed?(xml)
          xml.name != 'Object' || (xml.has_attribute?('class') && xml_state.last[:allowed_classes].include?(xml['class']))
        end
        private :xml_tag_allowed?

        class NullHandler
          def initialize(tag)
            @tag = tag
          end
          def to_xml(_, _)
            raise Serializable::Exception, "Missing XML handler for #{@tag}"
          end
          def from_xml(_)
            raise Serializable::Exception, "Missing XML handler for #{@tag}"
          end
        end
        private_constant :NullHandler

        def xml_handlers
          @xml_handlers ||= {}
        end
        private :xml_handlers

        def register_xml_handler(handler)
          raise RuntimeError, "Duplicate XML handler for tag #{handler.tag}" if xml_handlers.has_key?(handler.tag.to_s)
          xml_handlers[handler.tag.to_s] = handler
        end

        def get_xml_handler(tag_or_value)
          h = xml_handlers[tag_or_value.to_s]
          unless h
            tag_or_value = ::Object.const_get(tag_or_value.to_s) unless tag_or_value.is_a?(::Class)
            h = xml_handlers.values.find { |hnd| hnd.klass > tag_or_value } || NullHandler.new(tag_or_value)
          end
          h
        end

        def to_xml(xml, value)
          if Serializable === value
            value.to_xml(xml)
          else
            hk = case value
                 when true, false
                   value.to_s
                 else
                   value ? value.class : 'nil'
                 end
            get_xml_handler(hk).to_xml(xml, value)
          end
        end

        def from_xml(xml)
          raise Serializable::Exception, "Illegal XML tag #{xml.name}" unless xml_tag_allowed?(xml)
          get_xml_handler(xml.name).from_xml(xml)
        end

      end

      module ObjectHandler
        def self.klass
          FIRM::Serializable
        end
        def self.tag
          :Object
        end
        def self.to_xml(_, _)
          raise Serializable::Exception, 'Unsupported Object serialization'
        end
        def self.from_xml(xml)
          raise Serializable::Exception, 'Missing Serializable class name' unless xml.has_attribute?('class')
          Object.const_get(xml['class']).from_xml(xml)
        end
      end

      module NilHandler
        def self.klass
          NilClass
        end
        def self.tag
          :nil
        end
        def self.to_xml(xml, _value)
          xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document))
          xml
        end
        def self.from_xml(xml)
          nil
        end
      end

      module TrueHandler
        def self.klass
          ::TrueClass
        end
        def self.tag
          :true
        end
        def self.to_xml(xml, _value)
          xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document))
          xml
        end
        def self.from_xml(xml)
          true
        end
      end

      module FalseHandler
        def self.klass
          ::FalseClass
        end
        def self.tag
          :false
        end
        def self.to_xml(xml, _value)
          xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document))
          xml
        end
        def self.from_xml(xml)
          false
        end
      end

      module ArrayHandler
        def self.klass
          ::Array
        end
        def self.tag
          klass
        end
        def self.to_xml(xml, value)
          node = xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document))
          value.each do |v|
            Serializable::XML.to_xml(node, v)
          end
          xml
        end
        def self.from_xml(xml)
          xml.elements.collect { |child| Serializable::XML.from_xml(child) }
        end
      end

      module StringHandler
        def self.klass
          ::String
        end
        def self.tag
          klass
        end
        def self.to_xml(xml, value)
          xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document)).add_child(Nokogiri::XML::CDATA.new(xml.document, value))
          xml
        end
        def self.from_xml(xml)
          xml.content
        end
      end

      module SymbolHandler
        def self.klass
          ::Symbol
        end
        def self.tag
          klass
        end
        def self.to_xml(xml, value)
          xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document)).content = value.to_s
          xml
        end
        def self.from_xml(xml)
          xml.content.to_sym
        end
      end

      module IntegerHandler
        def self.klass
          ::Integer
        end
        def self.tag
          klass
        end
        def self.to_xml(xml, value)
          xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document)).content = value.to_s
          xml
        end
        def self.from_xml(xml)
          Integer(xml.content)
        end
      end

      module FloatHandler
        def self.klass
          ::Float
        end
        def self.tag
          klass
        end
        def self.to_xml(xml, value)
          xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document)).add_child(Nokogiri::XML::CDATA.new(xml.document, value.to_s))
          xml
        end
        def self.from_xml(xml)
          Float(xml.content)
        end
      end

      module ArrayHandler
        def self.klass
          ::Array
        end
        def self.tag
          klass
        end
        def self.to_xml(xml, value)
          node = xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document))
          value.each do |v|
            Serializable::XML.to_xml(node, v)
          end
          xml
        end
        def self.from_xml(xml)
          xml.elements.collect { |child| Serializable::XML.from_xml(child) }
        end
      end

      module HashHandler
        def self.klass
          ::Hash
        end
        def self.tag
          klass
        end
        def self.to_xml(xml, value)
          node = xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document))
          value.each_pair do |k,v|
            pair = node.add_child(Nokogiri::XML::Node.new('P', node.document))
            Serializable::XML.to_xml(pair, k)
            Serializable::XML.to_xml(pair, v)
          end
          xml
        end
        def self.from_xml(xml)
          xml.elements.inject({}) do |hash, pair|
            k, v = pair.elements
            hash[Serializable::XML.from_xml(k)] = Serializable::XML.from_xml(v)
            hash
          end
        end
      end

      module StructHandler
        def self.klass
          ::Struct
        end
        def self.tag
          klass
        end
        def self.to_xml(xml, value)
          node = xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document))
          node['class'] = value.class.name
          value.each do |v|
            Serializable::XML.to_xml(node, v)
          end
          xml
        end
        def self.from_xml(xml)
          ::Object.const_get(xml['class']).new(*xml.elements.collect { |child| Serializable::XML.from_xml(child) })
        end
      end

      module RangeHandler
        def self.klass
          ::Range
        end
        def self.tag
          klass
        end
        def self.to_xml(xml, value)
          node = xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document))
          Serializable::XML.to_xml(node, value.begin)
          Serializable::XML.to_xml(node, value.end)
          Serializable::XML.to_xml(node, value.exclude_end?)
        end
        def self.from_xml(xml)
          ::Range.new(*xml.elements.collect { |child| Serializable::XML.from_xml(child) })
        end
      end

      module SetHandler
        def self.klass
          ::Set
        end
        def self.tag
          klass
        end
        def self.to_xml(xml, value)
          node = xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document))
          value.each do |v|
            Serializable::XML.to_xml(node, v)
          end
          xml
        end
        def self.from_xml(xml)
          ::Set.new(xml.elements.collect { |child| Serializable::XML.from_xml(child) })
        end
      end

      module OpenStructHandler
        def self.klass
          ::OpenStruct
        end
        def self.tag
          klass
        end
        def self.to_xml(xml, value)
          node = xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document))
          value.each_pair do |k,v|
            pair = node.add_child(Nokogiri::XML::Node.new('P', node.document))
            Serializable::XML.to_xml(pair, k)
            Serializable::XML.to_xml(pair, v)
          end
          xml
        end
        def self.from_xml(xml)
          xml.elements.inject(::OpenStruct.new) do |hash, pair|
            k, v = pair.elements
            hash[Serializable::XML.from_xml(k)] = Serializable::XML.from_xml(v)
            hash
          end
        end
      end

      register_xml_handler(ObjectHandler)
      register_xml_handler(NilHandler)
      register_xml_handler(TrueHandler)
      register_xml_handler(FalseHandler)
      register_xml_handler(StringHandler)
      register_xml_handler(SymbolHandler)
      register_xml_handler(IntegerHandler)
      register_xml_handler(FloatHandler)
      register_xml_handler(ArrayHandler)
      register_xml_handler(HashHandler)
      register_xml_handler(StructHandler)
      register_xml_handler(RangeHandler)
      register_xml_handler(SetHandler)
      register_xml_handler(OpenStructHandler)

      class HashAdapter
        def initialize(xml)
          @xml = xml
        end

        def has_key?(id)
          !!@xml.at_xpath(id.to_s)
        end

        def [](id)
          node = @xml.at_xpath(id.to_s)
          node = node ? node.first_element_child : nil
          node ? Serializable::XML.from_xml(node) : nil
        end

        def []=(id, value)
          Serializable::XML.to_xml(@xml.add_child(Nokogiri::XML::Node.new(id.to_s, @xml.document)), value)
        end
      end

      def self.dump(obj, io=nil, pretty: false)
        begin
          # initialize anchor registry
          Serializable::Aliasing.start_anchor_registry
          # generate XML document
          xml = to_xml(Nokogiri::XML::Document.new, obj)
          opts = pretty ? { indent: 2 } : { }
          if io || io.respond_to?(:write)
            xml.write_xml_to(io, opts)
            io
          else
            xml.to_xml(opts)
          end
        ensure
          # reset anchor registry
          Serializable::Aliasing.clear_anchor_registry
        end
      end

      def self.load(source)
        xml = Nokogiri::XML(source)
        return nil unless xml
        begin
          # initialize ID restoration map
          Serializable::ID.init_restoration_map
          # initialize alias anchor restoration map
          Serializable::Aliasing.start_anchor_references
          # initialize XML loader state
          Serializable::XML.init_xml_load_state
          # load from xml doc
          xml.root ? Serializable::XML.from_xml(xml.root) : nil
        ensure
          # reset XML loader state
          Serializable::XML.clear_xml_load_state
          # reset alias anchor restoration map
          Serializable::Aliasing.clear_anchor_references
          # reset ID restoration map
          Serializable::ID.clear_restoration_map
        end
      end

    end

    # extend serialization class methods
    module SerializeClassMethods

      def from_xml(xml)
        data = XML::HashAdapter.new(xml)
        if self.allows_aliases?
          # deserializing anchor or alias
          if xml.has_attribute?('anchor')
            instance = create_for_deserialize(data)
                         .__send__(:from_serialized, data)
                         .__send__(:finalize_from_serialized)
            Serializable::Aliasing.restore_anchor(
              Serializable::ID.create_for_deserialize({ id: xml['anchor'].to_i }),
              instance)
          elsif xml.has_attribute?('alias')
            Serializable::Aliasing.resolve_anchor(
              self,
              Serializable::ID.create_for_deserialize({ id: xml['alias'].to_i }))
          else
            raise Serializable::Exception, 'Aliasable instance misses anchor or alias id'
          end
        else
          create_for_deserialize(data)
            .__send__(:from_serialized, data)
            .__send__(:finalize_from_serialized)
        end
      end

    end

    # extend instance serialization methods
    module SerializeInstanceMethods

      def to_xml(xml)
        node = xml.add_child(Nokogiri::XML::Node.new('Object', xml.document))
        node['class'] = self.class.name
        if self.class.allows_aliases? && Serializable::Aliasing.anchored?(self)
          node['alias'] = "#{Serializable::Aliasing.get_anchor(self).to_i}"
        else
          node['anchor'] = "#{Serializable::Aliasing.create_anchor(self).to_i}" if self.class.allows_aliases?
          for_serialize(XML::HashAdapter.new(node))
        end
        xml
      end

    end

    # extend Serializable::ID class
    class ID

      def self.from_xml(xml)
        # does not need calls to #from_serialized or #finalize_from_serialized
        create_for_deserialize(XML::HashAdapter.new(xml))
      end

      def to_xml(xml)
        node = xml.add_child(Nokogiri::XML::Node.new('Object', xml.document))
        node['class'] = self.class.name
        for_serialize(XML::HashAdapter.new(node))
      end

    end

    register(:xml, XML) if ::Object.const_defined?(:Nokogiri)

  end

end
