source ENV['GEM_SOURCE'] || 'https://rubygems.org'

group :development, :test do
  gem 'puppetlabs_spec_helper', :require => false
  gem 'puppet-lint', '~> 0.3.2'
  gem 'rake', '10.1.1'
  gem 'rspec-puppet', '~>1.0'
  gem 'puppet-syntax'
end

if puppetversion = ENV['PUPPET_GEM_VERSION']
    gem 'puppet', puppetversion, :require => false
else
    gem 'puppet', :require => false
end
