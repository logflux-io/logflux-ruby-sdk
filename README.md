# LogFlux Agent Ruby SDK

A lightweight Ruby SDK for communicating with the LogFlux Agent via Unix socket or TCP protocols.

## Requirements

- Ruby 2.7.0 or higher
- Bundler

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'logflux-agent-ruby-sdk'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install logflux-agent-ruby-sdk
```

## Quick Start

### Basic Usage

```ruby
require 'logflux'

# Create a Unix socket client (recommended)
client = LogFlux::Client.unix_client('/tmp/logflux-agent.sock')

begin
  # Connect to the agent
  client.connect

  # Create and send a log entry
  entry = LogFlux::LogEntry.new('Hello from Ruby!')
    .with_source('my-ruby-app')
    .with_level(LogFlux::LogEntry::LEVEL_INFO)
    .with_label('component', 'example')

  client.send_log_entry(entry)

  puts 'Log sent successfully!'

rescue LogFlux::Client::ConnectionError => e
  puts "Error: #{e.message}"
ensure
  client.close
end
```

### TCP Connection

```ruby
# Create a TCP client
client = LogFlux::Client.tcp_client('localhost', 9999)
```

### Using Factory Methods

```ruby
# Use factory methods for cleaner code
unix_client = LogFlux::Client.unix_client('/tmp/logflux-agent.sock')
tcp_client = LogFlux::Client.tcp_client('localhost', 9999)
```

## Log Levels

The SDK supports standard syslog levels:

```ruby
LogFlux::LogEntry::LEVEL_EMERGENCY  # 0 - Emergency
LogFlux::LogEntry::LEVEL_ALERT      # 1 - Alert  
LogFlux::LogEntry::LEVEL_CRITICAL   # 2 - Critical
LogFlux::LogEntry::LEVEL_ERROR      # 3 - Error
LogFlux::LogEntry::LEVEL_WARNING    # 4 - Warning
LogFlux::LogEntry::LEVEL_NOTICE     # 5 - Notice
LogFlux::LogEntry::LEVEL_INFO       # 6 - Info
LogFlux::LogEntry::LEVEL_DEBUG      # 7 - Debug
```

## Entry Types

```ruby
LogFlux::LogEntry::TYPE_LOG    # 1 - Standard log messages
LogFlux::LogEntry::TYPE_METRIC # 2 - Metrics data
LogFlux::LogEntry::TYPE_TRACE  # 3 - Distributed tracing
LogFlux::LogEntry::TYPE_EVENT  # 4 - Application events
LogFlux::LogEntry::TYPE_AUDIT  # 5 - Audit logs
```

## Payload Types

The SDK supports payload type hints for better log processing:

```ruby
# Specific payload types with convenience methods
syslog_entry = LogFlux::LogEntry.new_syslog_entry('kernel: USB disconnect')
journal_entry = LogFlux::LogEntry.new_systemd_journal_entry('Started SSH daemon')
metric_entry = LogFlux::LogEntry.new_metric_entry('{"cpu_usage": 45.2}')
container_entry = LogFlux::LogEntry.new_container_entry('[nginx] GET /health')

# Manual payload type assignment
entry = LogFlux::LogEntry.new('Custom log message')
  .with_payload_type(LogFlux::LogEntry::PAYLOAD_TYPE_APPLICATION)

# Automatic JSON detection
json_entry = LogFlux::LogEntry.new_generic_entry('{"user": "admin"}') 
# Automatically detected as PAYLOAD_TYPE_GENERIC_JSON
```

## Advanced Usage

### Custom Labels and Metadata

```ruby
entry = LogFlux::LogEntry.new('User login attempt')
  .with_source('auth-service')
  .with_level(LogFlux::LogEntry::LEVEL_INFO)
  .with_label('user_id', '12345')
  .with_label('ip_address', '192.168.1.100')
  .with_label('success', 'true')
  .with_payload_type(LogFlux::LogEntry::PAYLOAD_TYPE_AUDIT)

client.send_log_entry(entry)
```

### Error Handling with Retry Logic

```ruby
def send_log_with_retry(client, entry, max_retries = 3)
  (1..max_retries).each do |attempt|
    begin
      client.send_log_entry(entry)
      return # Success
    rescue LogFlux::Client::ConnectionError => e
      puts "Attempt #{attempt} failed: #{e.message}"
      
      raise e if attempt == max_retries
      
      # Wait before retry
      sleep(attempt)
    end
  end
end
```

### Rails Integration

```ruby
# config/initializers/logflux.rb
Rails.application.configure do
  config.logflux_client = LogFlux::Client.unix_client('/tmp/logflux-agent.sock')
  config.logflux_client.connect
  
  # Close connection on shutdown
  at_exit { config.logflux_client.close }
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  around_action :log_request

  private

  def log_request
    start_time = Time.now
    yield
  ensure
    duration = ((Time.now - start_time) * 1000).round(2)
    
    entry = LogFlux::LogEntry.new_application_entry("#{request.method} #{request.path}")
      .with_source('rails-app')
      .with_level(LogFlux::LogEntry::LEVEL_INFO)
      .with_label('method', request.method)
      .with_label('path', request.path)
      .with_label('status_code', response.status.to_s)
      .with_label('duration_ms', duration.to_s)
      .with_label('controller', controller_name)
      .with_label('action', action_name)
    
    Rails.application.config.logflux_client.send_log_entry(entry)
  rescue LogFlux::Client::ConnectionError => e
    Rails.logger.error "LogFlux error: #{e.message}"
  end
end
```

### Sinatra Integration

```ruby
require 'sinatra'
require 'logflux'

# Initialize client
configure do
  set :logflux_client, LogFlux::Client.unix_client('/tmp/logflux-agent.sock')
  settings.logflux_client.connect
end

# Logging helper
helpers do
  def log_to_logflux(message, level = LogFlux::LogEntry::LEVEL_INFO, **labels)
    entry = LogFlux::LogEntry.new(message)
      .with_source('sinatra-app')
      .with_level(level)
      
    labels.each { |k, v| entry.with_label(k.to_s, v.to_s) }
    
    settings.logflux_client.send_log_entry(entry)
  rescue LogFlux::Client::ConnectionError => e
    logger.error "LogFlux error: #{e.message}"
  end
end

get '/users/:id' do
  log_to_logflux('User accessed', user_id: params[:id], endpoint: '/users/:id')
  # Your route logic here
end
```

### Custom Logger Integration

```ruby
require 'logger'
require 'logflux'

class LogFluxLogger < Logger
  def initialize(logdev = nil, **options)
    super(logdev, **options)
    @logflux_client = LogFlux::Client.unix_client('/tmp/logflux-agent.sock')
    @logflux_client.connect
  end

  def add(severity, message = nil, progname = nil)
    # Call original logger
    result = super
    
    # Send to LogFlux
    begin
      level_map = {
        Logger::FATAL => LogFlux::LogEntry::LEVEL_EMERGENCY,
        Logger::ERROR => LogFlux::LogEntry::LEVEL_ERROR,
        Logger::WARN => LogFlux::LogEntry::LEVEL_WARNING,
        Logger::INFO => LogFlux::LogEntry::LEVEL_INFO,
        Logger::DEBUG => LogFlux::LogEntry::LEVEL_DEBUG
      }
      
      entry = LogFlux::LogEntry.new_application_entry(message || progname || 'Log message')
        .with_source('ruby-logger')
        .with_level(level_map[severity] || LogFlux::LogEntry::LEVEL_INFO)
        .with_label('severity', format_severity(severity))
        .with_label('progname', progname) if progname
      
      @logflux_client.send_log_entry(entry)
    rescue LogFlux::Client::ConnectionError => e
      warn "LogFlux error: #{e.message}"
    end
    
    result
  end

  def close
    @logflux_client.close if @logflux_client
    super
  end
end

# Usage
logger = LogFluxLogger.new(STDOUT)
logger.info('Application started')
logger.error('Something went wrong')
```

### Metrics Collection

```ruby
require 'etc'

class SystemMetrics
  def initialize(client)
    @client = client
  end

  def collect_and_send
    metrics = {
      memory_usage: memory_usage_mb,
      cpu_count: Etc.nprocessors,
      load_average: load_average,
      uptime: uptime_seconds
    }

    entry = LogFlux::LogEntry.new_metric_entry(metrics.to_json)
      .with_source('ruby-metrics')
      .with_label('hostname', Socket.gethostname)
      .with_label('process_id', Process.pid.to_s)

    @client.send_log_entry(entry)
  rescue LogFlux::Client::ConnectionError => e
    warn "Failed to send metrics: #{e.message}"
  end

  private

  def memory_usage_mb
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  end

  def load_average
    File.read('/proc/loadavg').split.first.to_f
  rescue
    0.0
  end

  def uptime_seconds
    File.read('/proc/uptime').split.first.to_f
  rescue
    0.0
  end
end

# Usage
client = LogFlux::Client.unix_client('/tmp/logflux-agent.sock')
client.connect

metrics_collector = SystemMetrics.new(client)

# Collect metrics every 30 seconds
Thread.new do
  loop do
    metrics_collector.collect_and_send
    sleep 30
  end
end
```

### Background Job Integration (Sidekiq)

```ruby
# In your worker
class MyWorker
  include Sidekiq::Worker
  
  def perform(job_data)
    client = LogFlux::Client.unix_client('/tmp/logflux-agent.sock')
    client.connect
    
    start_time = Time.now
    
    begin
      # Your job logic here
      process_job(job_data)
      
      # Log successful completion
      entry = LogFlux::LogEntry.new('Job completed successfully')
        .with_source('sidekiq-worker')
        .with_level(LogFlux::LogEntry::LEVEL_INFO)
        .with_label('worker_class', self.class.name)
        .with_label('duration_ms', ((Time.now - start_time) * 1000).round(2).to_s)
        .with_label('status', 'success')
      
      client.send_log_entry(entry)
      
    rescue StandardError => e
      # Log job failure
      entry = LogFlux::LogEntry.new("Job failed: #{e.message}")
        .with_source('sidekiq-worker')
        .with_level(LogFlux::LogEntry::LEVEL_ERROR)
        .with_label('worker_class', self.class.name)
        .with_label('duration_ms', ((Time.now - start_time) * 1000).round(2).to_s)
        .with_label('status', 'failed')
        .with_label('error_class', e.class.name)
      
      client.send_log_entry(entry)
      raise
    ensure
      client.close
    end
  end
end
```

## Best Practices

1. **Use Unix sockets** for local communication (faster and more secure)
2. **Reuse client instances** when possible to avoid connection overhead
3. **Handle connection errors** gracefully with appropriate retry logic
4. **Set meaningful labels** for better log filtering and analysis
5. **Use appropriate log levels** to control verbosity
6. **Choose correct payload types** to help LogFlux route logs appropriately
7. **Close connections** properly to avoid resource leaks
8. **Use begin/ensure** blocks for cleanup

## Thread Safety

The `LogFlux::Client` is **not thread-safe**. If you need to send logs from multiple threads:

1. Create separate client instances for each thread
2. Use a mutex to synchronize access to a shared client
3. Use a thread-safe wrapper or connection pool

## Development

**Important: All testing, building, and releasing of this SDK is handled exclusively through GitHub Actions.**

There are no local build scripts, Makefiles, or test runners. This ensures consistent, reproducible builds and tests across all environments.

### GitHub Actions Workflows

The following workflows handle all SDK operations:

- **ruby-sdk-ci.yml**: Main CI pipeline - runs tests, linting, security scans, and builds the gem
- **ruby-sdk-test.yml**: Comprehensive test suite including unit, integration, performance, and stress tests  
- **ruby-sdk-release.yml**: Handles gem publishing to RubyGems and GitHub releases

### Contributing

To contribute to this SDK:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Push to your branch (`git push origin feature/my-feature`)
5. Open a Pull Request
6. GitHub Actions will automatically run all tests and checks

### Testing

Tests are automatically run on:
- Ruby 2.7, 3.0, 3.1, 3.2, 3.3
- Ubuntu, macOS, and Windows
- Every push and pull request

View test results in the GitHub Actions tab of the repository.

### Security

Security scanning is performed automatically on every push using:
- bundler-audit for dependency vulnerabilities
- RuboCop for code quality and security patterns

## License

This SDK is part of the LogFlux Agent project. See the main repository for license information.