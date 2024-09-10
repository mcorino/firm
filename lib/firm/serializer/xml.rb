# FIRM::Serializer - shape serializer module
# Copyright (c) M.J.N. Corino, The Netherlands

require 'date'
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

        module HandlerMethods
          def create_type_node(xml)
            xml.add_child(Nokogiri::XML::Node.new(tag.to_s, xml.document))
          end
          def to_xml(_, _)
            raise Serializable::Exception, "Missing serialization method for #{klass} XML handler"
          end
          def from_xml(xml)
            raise Serializable::Exception, "Missing serialization method for #{klass} XML handler"
          end
        end
        private_constant :HandlerMethods

        def xml_handlers
          @xml_handlers ||= {}
        end
        private :xml_handlers

        def register_xml_handler(handler)
          raise RuntimeError, "Duplicate XML handler for tag #{handler.tag}" if xml_handlers.has_key?(handler.tag.to_s)
          xml_handlers[handler.tag.to_s] = handler
        end
        private :register_xml_handler

        def get_xml_handler(tag_or_value)
          h = xml_handlers[tag_or_value.to_s]
          unless h
            tag_or_value = ::Object.const_get(tag_or_value.to_s) unless tag_or_value.is_a?(::Class)
            h = xml_handlers.values.find { |hnd| hnd.klass > tag_or_value } || NullHandler.new(tag_or_value)
          end
          h
        end
        private :get_xml_handler

        def define_xml_handler(klass, tag=nil, &block)
          hnd_klass = Class.new
          hnd_klass.singleton_class.include(HandlerMethods)
          tag_code = if tag
                       ::Symbol === tag ? ":#{tag}" : "'#{tag.to_s}'"
                     else
                       'klass'
                     end
          hnd_klass.singleton_class.class_eval <<~__CODE
            def klass; #{klass};  end
            def tag; #{tag_code}; end
          __CODE
          hnd_klass.singleton_class.class_eval &block if block_given?
          register_xml_handler(hnd_klass)
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

      define_xml_handler(FIRM::Serializable, :Object) do
        def to_xml(_, _)
          raise Serializable::Exception, 'Unsupported Object serialization'
        end
        def from_xml(xml)
          raise Serializable::Exception, 'Missing Serializable class name' unless xml.has_attribute?('class')
          Object.const_get(xml['class']).from_xml(xml)
        end
      end

      define_xml_handler(::NilClass, :nil) do
        def to_xml(xml, _value)
          create_type_node(xml)
          xml
        end
        def from_xml(_xml)
          nil
        end
      end

      define_xml_handler(::TrueClass, :true) do
        def to_xml(xml, _value)
          create_type_node(xml)
          xml
        end
        def from_xml(_xml)
          true
        end
      end

      define_xml_handler(::FalseClass, :false) do
        def to_xml(xml, _value)
          create_type_node(xml)
          xml
        end
        def from_xml(_xml)
          false
        end
      end

      define_xml_handler(::Array) do
        def to_xml(xml, value)
          node = create_type_node(xml)
          value.each do |v|
            Serializable::XML.to_xml(node, v)
          end
          xml
        end
        def from_xml(xml)
          xml.elements.collect { |child| Serializable::XML.from_xml(child) }
        end
      end

      define_xml_handler(::String) do
        def to_xml(xml, value)
          create_type_node(xml).add_child(Nokogiri::XML::CDATA.new(xml.document, value))
          xml
        end
        def from_xml(xml)
          xml.content
        end
      end

      define_xml_handler(::Symbol) do
        def to_xml(xml, value)
          create_type_node(xml).content = value.to_s
          xml
        end
        def from_xml(xml)
          xml.content.to_sym
        end
      end

      define_xml_handler(::Integer) do
        def to_xml(xml, value)
          create_type_node(xml).content = value.to_s
          xml
        end
        def from_xml(xml)
          Integer(xml.content)
        end
      end

      define_xml_handler(::Float) do
        def to_xml(xml, value)
          create_type_node(xml).add_child(Nokogiri::XML::CDATA.new(xml.document, value.to_s))
          xml
        end
        def from_xml(xml)
          case (s = xml.content)
          when 'NaN' then :Float::NAN
          when 'Infinity' then ::Float::INFINITY
          when '-Infinity' then -::Float::INFINITY
          else
            Float(s)
          end
        end
      end

      define_xml_handler(::Hash) do
        def to_xml(xml, value)
          node = create_type_node(xml)
          value.each_pair do |k,v|
            pair = node.add_child(Nokogiri::XML::Node.new('P', node.document))
            Serializable::XML.to_xml(pair, k)
            Serializable::XML.to_xml(pair, v)
          end
          xml
        end
        def from_xml(xml)
          xml.elements.inject({}) do |hash, pair|
            k, v = pair.elements
            hash[Serializable::XML.from_xml(k)] = Serializable::XML.from_xml(v)
            hash
          end
        end
      end

      define_xml_handler(::Struct) do
        def to_xml(xml, value)
          node = create_type_node(xml)
          node['class'] = value.class.name
          value.each do |v|
            Serializable::XML.to_xml(node, v)
          end
          xml
        end
        def from_xml(xml)
          ::Object.const_get(xml['class']).new(*xml.elements.collect { |child| Serializable::XML.from_xml(child) })
        end
      end

      define_xml_handler(::Rational) do
        def to_xml(xml, value)
          node = create_type_node(xml)
          Serializable::XML.to_xml(node, value.numerator)
          Serializable::XML.to_xml(node, value.denominator)
          xml
        end
        def from_xml(xml)
          Rational(*xml.elements.collect { |child| Serializable::XML.from_xml(child) })
        end
      end

      define_xml_handler(::Complex) do
        def to_xml(xml, value)
          node = create_type_node(xml)
          Serializable::XML.to_xml(node, value.real)
          Serializable::XML.to_xml(node, value.imaginary)
          xml
        end
        def from_xml(xml)
          Complex(*xml.elements.collect { |child| Serializable::XML.from_xml(child) })
        end
      end

      if ::Object.const_defined?(:BigDecimal)
        define_xml_handler(::BigDecimal) do
          def to_xml(xml, value)
            create_type_node(xml).add_child(Nokogiri::XML::CDATA.new(xml.document, value._dump))
            xml
          end
          def from_xml(xml)
            ::BigDecimal._load(xml.content)
          end
        end
      end

      define_xml_handler(::Range) do
        def to_xml(xml, value)
          node = create_type_node(xml)
          Serializable::XML.to_xml(node, value.begin)
          Serializable::XML.to_xml(node, value.end)
          Serializable::XML.to_xml(node, value.exclude_end?)
          xml
        end
        def from_xml(xml)
          ::Range.new(*xml.elements.collect { |child| Serializable::XML.from_xml(child) })
        end
      end

      define_xml_handler(::Regexp) do
        def to_xml(xml, value)
          node = create_type_node(xml)
          Serializable::XML.to_xml(node, value.source)
          Serializable::XML.to_xml(node, value.options)
          xml
        end
        def from_xml(xml)
          ::Regexp.new(*xml.elements.collect { |child| Serializable::XML.from_xml(child) })
        end
      end

      define_xml_handler(::Time) do
        def to_xml(xml, value)
          node = create_type_node(xml)
          utc = value.getutc
          Serializable::XML.to_xml(node, utc.tv_sec)
          Serializable::XML.to_xml(node, utc.tv_nsec)
          xml
        end
        def from_xml(xml)
          ::Time.at(*xml.elements.collect { |child| Serializable::XML.from_xml(child) }, :nanosecond)
        end
      end

      define_xml_handler(::Date) do
        def to_xml(xml, value)
          node = create_type_node(xml)
          idt = value.italy
          Serializable::XML.to_xml(node, idt.year)
          Serializable::XML.to_xml(node, idt.month)
          Serializable::XML.to_xml(node, idt.day)
          xml
        end
        def from_xml(xml)
          ::Date.new(*xml.elements.collect { |child| Serializable::XML.from_xml(child) }, ::Date::ITALY)
        end
      end

      define_xml_handler(::DateTime) do
        def to_xml(xml, value)
          node = create_type_node(xml)
          idt = value.italy
          Serializable::XML.to_xml(node, idt.year)
          Serializable::XML.to_xml(node, idt.month)
          Serializable::XML.to_xml(node, idt.day)
          Serializable::XML.to_xml(node, idt.hour)
          Serializable::XML.to_xml(node, idt.min)
          Serializable::XML.to_xml(node, idt.sec_fraction.to_f + idt.sec)
          Serializable::XML.to_xml(node, idt.offset)
          xml
        end
        def from_xml(xml)
          ::DateTime.new(*xml.elements.collect { |child| Serializable::XML.from_xml(child) }, ::Date::ITALY)
        end
      end

      define_xml_handler(::Set) do
        def to_xml(xml, value)
          node = create_type_node(xml)
          value.each do |v|
            Serializable::XML.to_xml(node, v)
          end
          xml
        end
        def from_xml(xml)
          ::Set.new(xml.elements.collect { |child| Serializable::XML.from_xml(child) })
        end
      end

      define_xml_handler(::OpenStruct) do
        def to_xml(xml, value)
          node = create_type_node(xml)
          value.each_pair do |k,v|
            pair = node.add_child(Nokogiri::XML::Node.new('P', node.document))
            Serializable::XML.to_xml(pair, k)
            Serializable::XML.to_xml(pair, v)
          end
          xml
        end
        def from_xml(xml)
          xml.elements.inject(::OpenStruct.new) do |hash, pair|
            k, v = pair.elements
            hash[Serializable::XML.from_xml(k)] = Serializable::XML.from_xml(v)
            hash
          end
        end
      end

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
          opts = pretty ? { indent: 2 } : { save_with: 0 }
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
