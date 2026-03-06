
require 'minitest/autorun'
require_relative './serializer_tests'

class YamlSerializeTests < Minitest::Test

  include SerializerTestMixin

  def setup
    FIRM::Serializable.default_format = :yaml
  end

  def teardown
    FIRM::Serializable.default_format = nil
  end

end
