# FIRM::Serializer - shape serializer module
# Copyright (c) M.J.N. Corino, The Netherlands


require 'set'
# from Ruby 3.5.0 OpenStruct will not be available by default anymore
begin
  require 'ostruct'
rescue LoadError
end
require 'date'

module FIRM

  module Serializable

    if ::Object.const_defined?(:Nokogiri)

      module XML

        class << self

          TLS_STATE_KEY = :firm_xml_state.freeze
          private_constant :TLS_STATE_KEY

          def xml_state
            Serializable.tls_vars[TLS_STATE_KEY] ||= []
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
            private :create_type_node
            def to_xml(_, _)
              raise Serializable::Exception, "Missing serialization method for #{klass} XML handler"
            end
            def from_xml(xml)
              raise Serializable::Exception, "Missing serialization method for #{klass} XML handler"
            end
          end
          private_constant :HandlerMethods

          module AliasableHandler
            def build_xml(xml, value, &block)
              node = create_type_node(xml)
              node['class'] = value.class.name
              if (anchor = Serializable::Aliasing.get_anchor(value))
                anchor_data = Serializable::Aliasing.get_anchor_data(value)
                # retroactively insert the anchor in the anchored instance's serialization data
                anchor_data['anchor'] = anchor unless anchor_data.has_attribute?('anchor')
                node['alias'] = "#{anchor}"
              else
                # register anchor object **before** serializing properties to properly handle cycling (bidirectional
                # references)
                Serializable::Aliasing.register_anchor_object(value, node)
                block.call(node)
              end
              xml
            end
            private :build_xml
            def create_from_xml(xml, &block)
              klass = ::Object.const_get(xml['class'])
              if xml.has_attribute?('alias')
                # deserializing alias
                Serializable::Aliasing.resolve_anchor(klass, xml['alias'].to_i)
              else
                instance = klass.new
                # in case this is an anchor restore the anchor instance before restoring the member values
                # and afterwards initialize the instance with the restored member values
                Serializable::Aliasing.restore_anchor(xml['anchor'].to_i, instance) if xml.has_attribute?('anchor')
                block.call(instance)
                instance
              end
            end
            private :create_from_xml
          end
          private_constant :AliasableHandler

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

          def define_xml_handler(klass, tag=nil, aliasable: false, &block)
            hnd_klass = Class.new
            hnd_klass.singleton_class.include(HandlerMethods)
            hnd_klass.singleton_class.include(AliasableHandler) if aliasable
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

        # registered as tag 'Class' but that is never actually used
        define_xml_handler(::Class, 'Class') do
          # overload to emit 'String' tags
          def create_type_node(xml)
            xml.add_child(Nokogiri::XML::Node.new('String', xml.document))
          end
          def to_xml(xml, value)
            create_type_node(xml).add_child(Nokogiri::XML::CDATA.new(xml.document, value.name))
            xml
          end
          def from_xml(xml)
            # should never be called
            raise Serializable::Exception, 'Unsupported Class deserialization'
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

        define_xml_handler(::Array, aliasable: true) do
          def to_xml(xml, value)
            build_xml(xml, value) { |node| value.each { |v| Serializable::XML.to_xml(node, v) } }
          end
          def from_xml(xml)
            create_from_xml(xml) do |instance|
              instance.replace(xml.elements.collect { |child| Serializable::XML.from_xml(child) })
            end
          end
        end

        define_xml_handler(::String) do
          def to_xml(xml, value)
            create_type_node(xml).add_child(Nokogiri::XML::CDATA.new(xml.document, value))
            xml
          end
          def from_xml(xml)
            # in case the xml was somehow formatted it may be additional text nodes
            # get inserted because of added space and/or newlines
            # (like with JRuby's Nokogiri when outputting pretty formatted XML)
            # so just in case look up the one CDATA child and only use that one's content
            xml.children.find { |child| child.cdata? }&.text || ''
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
            s = xml.children.find { |child| child.cdata? }&.text
            case s
            when nil, 'NaN' then :Float::NAN
            when 'Infinity' then ::Float::INFINITY
            when '-Infinity' then -::Float::INFINITY
            else
              Float(s)
            end
          end
        end

        define_xml_handler(::Hash, aliasable: true) do
          def to_xml(xml, value)
            build_xml(xml, value) do |node|
              value.each_pair do |k,v|
                pair = node.add_child(Nokogiri::XML::Node.new('P', node.document))
                Serializable::XML.to_xml(pair, k)
                Serializable::XML.to_xml(pair, v)
              end
            end
          end
          def from_xml(xml)
            create_from_xml(xml) do |instance|
              xml.elements.inject(instance) do |hash, pair|
                k, v = pair.elements
                instance[Serializable::XML.from_xml(k)] = Serializable::XML.from_xml(v)
                instance
              end
            end
          end
        end

        define_xml_handler(::Struct, aliasable: true) do
          def to_xml(xml, value)
            build_xml(xml, value) { |node| value.each { |v| Serializable::XML.to_xml(node, v) } }
          end
          def from_xml(xml)
            create_from_xml(xml) do |instance|
              elems = xml.elements
              instance.members.each_with_index { |n, i| instance[n] = Serializable::XML.from_xml(elems[i]) }
            end
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
              # in case the xml was somehow formatted it may be additional text nodes
              # get inserted because of added space and/or newlines
              # (like with JRuby's Nokogiri when outputting pretty formatted XML)
              # so just in case look up the one CDATA child and only use that one's content
              data = xml.children.find { |child| child.cdata? }&.text
              ::BigDecimal._load(data || '')
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

        define_xml_handler(::Set, aliasable: true) do
          def to_xml(xml, value)
            build_xml(xml, value) { |node| value.each { |v| Serializable::XML.to_xml(node, v) } }
          end
          def from_xml(xml)
            create_from_xml(xml) do |instance|
              instance.replace(xml.elements.collect { |child| Serializable::XML.from_xml(child) })
            end
          end
        end

        if ::Object.const_defined?(:OpenStruct)
          define_xml_handler(::OpenStruct, aliasable: true) do
            def to_xml(xml, value)
              build_xml(xml, value) do |node|
                value.each_pair do |k,v|
                  pair = node.add_child(Nokogiri::XML::Node.new('P', node.document))
                  Serializable::XML.to_xml(pair, k)
                  Serializable::XML.to_xml(pair, v)
                end
              end
            end
            def from_xml(xml)
              create_from_xml(xml) do |instance|
                xml.elements.inject(::OpenStruct.new) do |hash, pair|
                  k, v = pair.elements
                  instance[Serializable::XML.from_xml(k)] = Serializable::XML.from_xml(v)
                  instance
                end
              end
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
            Serializable::Aliasing.start_anchor_object_registry
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
            Serializable::Aliasing.clear_anchor_object_registry
          end
        end

        def self.load(source)
          xml = Nokogiri::XML(source)
          return nil unless xml
          begin
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
          end
        end

        # extend serialization class methods
        module SerializeClassMethods

          def from_xml(xml)
            data = XML::HashAdapter.new(xml)
            # deserializing alias
            if xml.has_attribute?('alias')
              Serializable::Aliasing.resolve_anchor(self, xml['alias'].to_i)
            else
              instance = self.allocate
              Serializable::Aliasing.restore_anchor(xml['anchor'].to_i, instance) if xml.has_attribute?('anchor')
              instance.__send__(:init_from_serialized, data)
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
            if (anchor = Serializable::Aliasing.get_anchor(self))
              anchor_data = Serializable::Aliasing.get_anchor_data(self)
              # retroactively insert the anchor in the anchored instance's serialization data
              anchor_data['anchor'] = anchor unless anchor_data.has_attribute?('anchor')
              node['alias'] = "#{anchor}"
            else
              # register anchor object **before** serializing properties to properly handle cycling (bidirectional
              # references)
              Serializable::Aliasing.register_anchor_object(self, node)
              for_serialize(XML::HashAdapter.new(node))
            end
            xml
          end

        end

      end

      # extend serialization class methods
      module SerializeClassMethods

        include XML::SerializeClassMethods

      end

      # extend instance serialization methods
      module SerializeInstanceMethods

        include XML::SerializeInstanceMethods

      end

      class ID
        include XML::SerializeInstanceMethods
        class << self
          include XML::SerializeClassMethods
        end
      end

      register(:xml, XML)

    end

  end

end
