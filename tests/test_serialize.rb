
require 'test/unit'
require 'test/unit/ui/console/testrunner'
require_relative './serializer_tests'

class SerializeTests < Test::Unit::TestCase
  include SerializerTestMixin
end
