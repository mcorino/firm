###
# FIRM rake file
# Copyright (c) M.J.N. Corino, The Netherlands
###

require 'rake/packagetask'

Rake::PackageTask.new("firm", FIRM::FIRM_VERSION) do |p|
  p.need_tar_gz = true
  p.need_zip = true
  p.package_files.include(%w{lib/**/* tests/**/* rakelib/**/*})
  p.package_files.include(%w{LICENSE* Gemfile rakefile README.md .yardopts})
end
