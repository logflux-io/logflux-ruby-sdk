# frozen_string_literal: true

require 'bundler/setup'

# Enable SimpleCov for coverage if COVERAGE env var is set
if ENV['COVERAGE']
  require 'simplecov'
  
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
    add_group 'Library', 'lib'
    
    minimum_coverage 90
    
    # Generate different output formats
    formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::SimpleFormatter
    ])
  end
  
  puts "📊 Code coverage enabled"
end

require_relative '../lib/logflux'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Use expect syntax only (not should)
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Configure output format
  config.formatter = :documentation if ENV['CI']
  
  # Fail fast in CI environments
  config.fail_fast = true if ENV['CI']
  
  # Randomize test order
  config.order = :random
  Kernel.srand config.seed
  
  # Show slowest examples
  config.profile_examples = 10 if ENV['PROFILE']
  
  # Filter tests by tags
  config.filter_run_when_matching :focus
  config.run_all_when_everything_filtered = true
  
  # Configure warnings
  config.warnings = true
  
  # Before and after hooks
  config.before(:suite) do
    puts "🧪 Starting Ruby SDK test suite"
    puts "Ruby version: #{RUBY_VERSION}"
    puts "LogFlux version: #{LogFlux::VERSION}"
  end
  
  config.after(:suite) do
    puts "✅ Ruby SDK test suite completed"
  end
  
  config.before(:each) do
    # Reset any global state if needed
  end
  
  # Add custom matchers if needed
  config.include Module.new {
    # Custom matcher for JSON validation
    def be_valid_json
      satisfy("be valid JSON") do |actual|
        begin
          JSON.parse(actual)
          true
        rescue JSON::ParserError
          false
        end
      end
    end
    
    # Custom matcher for LogEntry validation
    def be_a_valid_log_entry
      satisfy("be a valid LogEntry") do |actual|
        actual.is_a?(LogFlux::LogEntry) &&
          !actual.message.nil? &&
          !actual.message.empty? &&
          actual.respond_to?(:to_json) &&
          actual.respond_to?(:to_h)
      end
    end
  }
end

# Global test helpers
def sample_log_entry(message = "Test message")
  LogFlux::LogEntry.new(message)
    .with_source("rspec-test")
    .with_label("test", "true")
    .with_label("timestamp", Time.now.to_i.to_s)
end

def sample_entries(count = 5)
  Array.new(count) { |i| sample_log_entry("Test message #{i + 1}") }
end

# Shared examples for common tests
RSpec.shared_examples "a serializable object" do
  it "responds to to_json" do
    expect(subject).to respond_to(:to_json)
  end
  
  it "responds to to_h" do
    expect(subject).to respond_to(:to_h)
  end
  
  it "produces valid JSON" do
    expect(subject.to_json).to be_valid_json
  end
end

RSpec.shared_examples "a chainable builder" do |method_name|
  it "returns self for method chaining" do
    expect(subject.public_send(method_name, "test_value")).to eq(subject)
  end
end

# Performance testing helpers (if benchmark gems are available)
begin
  require 'benchmark'
  
  def benchmark_example(description, &block)
    result = Benchmark.measure(&block)
    puts "⏱️  #{description}: #{result.real.round(4)}s"
    result
  end
rescue LoadError
  def benchmark_example(description, &block)
    yield
  end
end

# Test data generators
module TestDataGenerators
  def self.random_string(length = 10)
    (0...length).map { ('a'..'z').to_a[rand(26)] }.join
  end
  
  def self.large_message(size_kb = 1)
    "A" * (size_kb * 1024)
  end
  
  def self.unicode_message
    "Hello 世界 🌍 Testing unicode characters: αβγδε עברית العربية"
  end
  
  def self.json_payload
    {
      event: "test_event",
      timestamp: Time.now.to_i,
      data: {
        key1: "value1",
        key2: 12345,
        key3: true
      }
    }.to_json
  end
  
  def self.metric_payload
    {
      cpu_usage: 45.2,
      memory_usage: 1024,
      disk_usage: 75.5,
      network_in: 1000,
      network_out: 500
    }.to_json
  end
end