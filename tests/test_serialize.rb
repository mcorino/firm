
require 'minitest/autorun'
require_relative './serializer_tests'

class SerializeTests < Minitest::Test
  include SerializerTestMixin
end
