# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in logflux-agent-ruby-sdk.gemspec
gemspec

# Dependencies for GitHub Actions testing only
# DO NOT use these for local development
group :test do
  gem 'rake', '~> 13.0'
  gem 'rspec', '~> 3.0'
  gem 'rspec_junit_formatter'
  gem 'simplecov'
  gem 'simplecov-lcov'
end

group :development do
  gem 'rubocop', '~> 1.21'
  gem 'rubocop-rspec'
  gem 'rubocop-performance'
  gem 'yard', '~> 0.9'
  gem 'bundler-audit'
  gem 'benchmark-ips'
  gem 'benchmark-memory'
  gem 'get_process_mem'
end