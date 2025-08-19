# frozen_string_literal: true

# This Rakefile is for GitHub Actions use only
# All testing and building must be done through GitHub Actions

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc "Run tests with coverage"
task :coverage do
  ENV["COVERAGE"] = "true"
  Rake::Task[:spec].invoke
end

desc "This Rakefile is for GitHub Actions only"
task :info do
  puts "This Rakefile is for GitHub Actions use only."
  puts "All testing and building must be done through GitHub Actions."
  puts "See .github/workflows/ for the CI/CD pipeline."
end