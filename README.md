# LogFlux Ruby SDK

Official Ruby SDK for LogFlux Agent - A lightweight, high-performance log collection and forwarding agent.

[![Ruby CI](https://github.com/logflux-io/logflux-ruby-sdk/actions/workflows/ruby.yml/badge.svg)](https://github.com/logflux-io/logflux-ruby-sdk/actions/workflows/ruby.yml)
[![Gem Version](https://badge.fury.io/rb/logflux-sdk.svg)](https://badge.fury.io/rb/logflux-sdk)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## Quick Start

```ruby
require 'logflux'

begin
  client = LogFlux::Client.new("/tmp/logflux-agent.sock")
  client.connect
  client.send_log("Hello from LogFlux Ruby SDK!")
  client.close
rescue => e
  puts "Error: #{e.message}"
end
```

## Requirements

- Ruby 2.7 or higher
- Bundler

## Installation

### RubyGems

```bash
gem install logflux-sdk
```

### Bundler

Add this line to your application's Gemfile:

```ruby
gem 'logflux-sdk'
```

And then execute:

```bash
bundle install
```

## Usage Example

```ruby
require 'logflux'

begin
  # Create a client for Unix socket connection
  client = LogFlux::Client.new("/tmp/logflux-agent.sock")
  
  # Connect to the agent
  client.connect
  
  # Send a simple log message
  client.send_log("Hello from Ruby SDK!")
  
  # Send a structured log entry
  entry = LogFlux::LogEntry.new("Application started")
    .with_level(LogFlux::LogEntry::LEVEL_INFO)
    .with_source("my-app")
    .with_label("component", "web-server")
    .with_label("version", "1.0.0")
  
  client.send_log_entry(entry)
  
  client.close
  
rescue => e
  puts "Error: #{e.message}"
end
```

## Features

- Support for both Unix socket and TCP connections
- Automatic reconnection with exponential backoff
- Batch processing for high-throughput scenarios
- Thread-safe operations
- Minimal dependencies (only JSON)
- Ruby 2.7+ compatibility
- Simple and intuitive API

## Documentation

For full documentation, visit [LogFlux Documentation](https://docs.logflux.io)

## License

This SDK is distributed under the Apache License, Version 2.0. See the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues and questions, please use the GitHub issue tracker.
