#!/usr/bin/env ruby

require_relative '../lib/log_entry'
require_relative '../lib/client'

puts 'LogFlux Ruby SDK - Basic Example'
puts '================================'

begin
    # Create log entries to demonstrate API
    basic_entry = LogEntry.new('Hello from Ruby SDK!')
    
    detailed_entry = LogEntry.new('User login attempt')
        .with_source('ruby-example')
        .with_level(LogEntry::LEVEL_INFO)
        .with_label('user_id', '12345')
        .with_label('ip_address', '192.168.1.100')
    
    json_entry = LogEntry.new_generic_entry('{"event": "user_login", "success": true}')
    metric_entry = LogEntry.new_metric_entry('{"cpu_usage": 45.2, "memory": 1024}')
    
    # Display the entries (since we can't connect without an agent)
    puts 'Created log entries:'
    puts "1. Basic: #{basic_entry.message}"
    puts "2. Detailed: #{detailed_entry.message} (labels: #{detailed_entry.labels.size})"
    puts "3. JSON: #{json_entry.message} (type: #{json_entry.labels['payload_type']})"
    puts "4. Metric: #{metric_entry.message} (type: #{metric_entry.labels['payload_type']})"
    
    # Demonstrate JSON serialization
    puts "\nJSON representation of basic entry:"
    puts basic_entry.to_json
    
    puts "\n✅ Ruby SDK basic example completed successfully!"
    
rescue => e
    puts "❌ Error: #{e.message}"
    exit 1
end