require 'puppet-syntax/tasks/puppet-syntax'
require 'puppet-lint/tasks/puppet-lint'
require 'rspec/core/rake_task'
require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'

PuppetSyntax.exclude_paths = ["vendor/**/*"]
PuppetLint.configuration.ignore_paths = ["spec/**/*.pp", "vendor/**/*.pp"]

# The default for the config is /etc/puppet/puppet.conf, which means that if
# that file exists, it will be used, which contaminates the test environment.
# Tell it to use /dev/null so that it won't load a config at all.
Puppet.settings.override_default(:config, '/dev/null')

task(:default).clear
task :default => [ :lint, :syntax, :spec ]
