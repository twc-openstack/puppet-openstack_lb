require 'puppet-syntax/tasks/puppet-syntax'
require 'puppet-lint/tasks/puppet-lint'
require 'rspec/core/rake_task'
require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'

PuppetSyntax.exclude_paths = ["vendor/**/*"]
PuppetLint.configuration.ignore_paths = ["spec/**/*.pp", "vendor/**/*.pp"]

task(:default).clear
task :default => [ :lint, :syntax, :spec ]
