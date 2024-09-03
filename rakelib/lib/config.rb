###
# wxRuby3/Shapes rake configuration
# Copyright (c) M.J.N. Corino, The Netherlands
###

require 'rbconfig'
require 'fileutils'

module FIRM
  ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

  if defined? ::RbConfig
    RB_CONFIG = ::RbConfig::CONFIG
  else
    RB_CONFIG = ::Config::CONFIG
  end unless defined? RB_CONFIG

  # Ruby 2.5 is the minimum version for FIRM
  __rb_ver = RUBY_VERSION.split('.').collect {|v| v.to_i}
  if (__rb_major = __rb_ver.shift) < 2 || (__rb_major == 2 && __rb_ver.shift < 5)
    STDERR.puts 'ERROR: FIRM requires Ruby >= 2.5.0!'
    exit(1)
  end

  # Pure-ruby lib files
  ALL_RUBY_LIB_FILES = FileList[ 'lib/**/*.rb' ]

  # The version file
  VERSION_FILE = File.join(ROOT,'lib', 'firm', 'version.rb')

  if File.exist?(VERSION_FILE)
    require VERSION_FILE
    FIRM_VERSION = FIRM::VERSION
    # Leave version undefined
  else
    FIRM_VERSION = ''
  end

end # module FIRM
