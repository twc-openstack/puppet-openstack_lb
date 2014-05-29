require 'rubygems'
require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-parse/puppet-parse'
require 'puppet-lint/tasks/puppet-lint'

task(:default).clear
task :default => [ :lint, :parse ]

# We don't care about this because it is only an issue with ancient puppet.
PuppetLint.configuration.send('disable_class_parameter_defaults')
# We need quoted booleans because facter always returns strings
PuppetLint.configuration.send('disable_quoted_booleans')
