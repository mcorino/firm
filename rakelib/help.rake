###
# FIRM rake file
# Copyright (c) M.J.N. Corino, The Netherlands
###

module FIRM
  HELP = <<__HELP_TXT

FIRM Rake based build system
--------------------------------------

This build system provides commands for testing and installing FIRM.

commands:

rake <rake-options> help             # Provide help description about FIRM build system
rake <rake-options> gem              # Build FIRM gem
rake <rake-options> test             # Run all FIRM tests
rake <rake-options> package          # Build all the packages
rake <rake-options> repackage        # Force a rebuild of the package files
rake <rake-options> clobber_package  # Remove package products

__HELP_TXT
end

namespace :firm do
  task :help do
    puts FIRM::HELP
  end
end

desc 'Provide help description about FIRM build system'
task :help => 'firm:help'
