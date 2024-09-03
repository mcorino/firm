###
# FIRM rake file
# Copyright (c) M.J.N. Corino, The Netherlands
###

require_relative './gem'

namespace :firm do

  task :gem => [FIRM::Gem.gem_file('firm', FIRM::FIRM_VERSION)]

end

# source gem file
file FIRM::Gem.gem_file('firm', FIRM::FIRM_VERSION) => FIRM::Gem.manifest do
  gemspec = FIRM::Gem.define_spec('firm', FIRM::FIRM_VERSION) do |gem|
    gem.summary = %Q{Format independent Ruby object marshalling}
    gem.description = %Q{FIRM is a pure Ruby library providing format independent object marshalling}
    gem.email = 'mcorino@m2c-software.nl'
    gem.homepage = "https://github.com/mcorino/firm"
    gem.authors = ['Martin Corino']
    gem.files = FIRM::Gem.manifest
    gem.require_paths = %w{lib}
    gem.required_ruby_version = '>= 2.5'
    gem.licenses = ['MIT']
    gem.add_dependency 'rake'
    gem.add_dependency 'minitest', '~> 5.15'
    gem.add_dependency 'test-unit', '~> 3.5'
    gem.metadata = {
      "bug_tracker_uri"   => "https://github.com/mcorino/firm/issues",
      "source_code_uri"   => "https://github.com/mcorino/firm",
      "documentation_uri" => "https://mcorino.github.io/firm",
      "homepage_uri"      => "https://github.com/mcorino/firm",
    }
  end
  FIRM::Gem.build_gem(gemspec)
end

desc 'Build FIRM gem'
task :gem => 'firm:gem'
