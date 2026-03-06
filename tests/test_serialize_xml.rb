
require 'minitest/autorun'
require_relative './serializer_tests'

if ::Object.const_defined?(:Nokogiri)

  class XMLSerializeTests < Minitest::Test

    include SerializerTestMixin

    def setup
      FIRM::Serializable.default_format = :xml
    end

    def teardown
      FIRM::Serializable.default_format = nil
    end

  end

end
