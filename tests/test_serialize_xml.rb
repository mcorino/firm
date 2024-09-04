
require 'test/unit'
require 'test/unit/ui/console/testrunner'
require_relative './serializer_tests'

if ::Object.const_defined?(:Nokogiri)

  class XMLSerializeTests < Test::Unit::TestCase

    include SerializerTestMixin

    def self.startup
      FIRM::Serializable.default_format = :xml
    end

    def self.shutdown
      FIRM::Serializable.default_format = nil
    end

  end

end
