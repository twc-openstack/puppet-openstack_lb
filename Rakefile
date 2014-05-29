require 'puppet-parse/puppet-parse'
require 'puppet-lint/tasks/puppet-lint'
require 'rspec/core/rake_task'
require 'puppetlabs_spec_helper/rake_tasks'

require 'puppet-lint/tasks/puppet-lint'
PuppetLint.configuration.ignore_paths = ["spec/**/*.pp", "vendor/**/*.pp"]

task(:default).clear
task :default => [ :lint, :parse, :spec ]
