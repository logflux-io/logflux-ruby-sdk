require_relative '../lib/logflux/log_entry'
require 'json'
require 'time'

RSpec.describe LogFlux::LogEntry do
  describe '#initialize' do
    it 'creates a basic entry with default values' do
      entry = LogFlux::LogEntry.new('test message')
      expect(entry.message).to eq('test message')
      expect(entry.source).to eq('ruby-sdk')
      expect(entry.level).to eq(LogFlux::LogEntry::LEVEL_INFO)
      expect(entry.entry_type).to eq(LogFlux::LogEntry::TYPE_LOG)
      expect(entry.id).to be_a(String)
      expect(entry.id.length).to eq(36) # UUID format
      expect(entry.timestamp).to be_a(String)
      expect(entry.labels).to eq({})
    end

    it 'accepts nil message and converts to empty string' do
      entry = LogFlux::LogEntry.new(nil)
      expect(entry.message).to eq('')
    end

    it 'accepts non-string message and converts to string' do
      entry = LogFlux::LogEntry.new(12345)
      expect(entry.message).to eq('12345')
      
      entry2 = LogFlux::LogEntry.new({ key: 'value' })
      expect(entry2.message).to include('key')
      expect(entry2.message).to include('value')
    end

    it 'generates unique IDs for different entries' do
      entry1 = LogFlux::LogEntry.new('message 1')
      entry2 = LogFlux::LogEntry.new('message 2')
      expect(entry1.id).not_to eq(entry2.id)
    end

    it 'generates incrementing timestamps' do
      entry1 = LogFlux::LogEntry.new('message 1')
      sleep(0.001) # Small delay to ensure different timestamps
      entry2 = LogFlux::LogEntry.new('message 2')
      
      time1 = Time.parse(entry1.timestamp)
      time2 = Time.parse(entry2.timestamp)
      expect(time2).to be > time1
    end
  end

  describe 'builder pattern methods' do
    let(:entry) { LogFlux::LogEntry.new('test message') }

    describe '#with_source' do
      it 'sets the source and returns self' do
        result = entry.with_source('test-app')
        expect(result).to eq(entry)
        expect(entry.source).to eq('test-app')
      end

      it 'handles nil source' do
        entry.with_source(nil)
        expect(entry.source).to eq('')
      end

      it 'converts non-string source to string' do
        entry.with_source(123)
        expect(entry.source).to eq('123')
      end
    end

    describe '#with_level' do
      it 'sets valid log levels' do
        [
          LogFlux::LogEntry::LEVEL_DEBUG,
          LogFlux::LogEntry::LEVEL_INFO,
          LogFlux::LogEntry::LEVEL_WARN,
          LogFlux::LogEntry::LEVEL_ERROR,
          LogFlux::LogEntry::LEVEL_FATAL
        ].each do |level|
          test_entry = LogFlux::LogEntry.new('test')
          result = test_entry.with_level(level)
          expect(result).to eq(test_entry)
          expect(test_entry.level).to eq(level)
        end
      end

      it 'defaults to INFO for invalid levels' do
        entry.with_level('invalid')
        expect(entry.level).to eq(LogFlux::LogEntry::LEVEL_INFO)
        
        entry.with_level(999)
        expect(entry.level).to eq(LogFlux::LogEntry::LEVEL_INFO)
      end
    end

    describe '#with_label' do
      it 'adds a single label' do
        result = entry.with_label('key1', 'value1')
        expect(result).to eq(entry)
        expect(entry.labels).to eq({ 'key1' => 'value1' })
      end

      it 'adds multiple labels' do
        entry
          .with_label('key1', 'value1')
          .with_label('key2', 'value2')
          .with_label('key3', 'value3')
        
        expect(entry.labels).to eq({
          'key1' => 'value1',
          'key2' => 'value2',
          'key3' => 'value3'
        })
      end

      it 'overwrites existing labels' do
        entry
          .with_label('key', 'value1')
          .with_label('key', 'value2')
        
        expect(entry.labels).to eq({ 'key' => 'value2' })
      end

      it 'handles nil keys and values' do
        entry.with_label(nil, 'value')
        expect(entry.labels).to eq({ '' => 'value' })
        
        entry.with_label('key', nil)
        expect(entry.labels).to eq({ '' => 'value', 'key' => '' })
      end

      it 'converts non-string keys and values to strings' do
        entry
          .with_label(123, 456)
          .with_label(:symbol, true)
        
        expect(entry.labels).to eq({
          '123' => '456',
          'symbol' => 'true'
        })
      end
    end

    it 'supports full method chaining' do
      result = LogFlux::LogEntry.new('chained message')
        .with_source('chain-test')
        .with_level(LogFlux::LogEntry::LEVEL_ERROR)
        .with_label('env', 'production')
        .with_label('version', '1.0.0')
        .with_label('host', 'server01')

      expect(result.message).to eq('chained message')
      expect(result.source).to eq('chain-test')
      expect(result.level).to eq(LogFlux::LogEntry::LEVEL_ERROR)
      expect(result.labels).to eq({
        'env' => 'production',
        'version' => '1.0.0',
        'host' => 'server01'
      })
    end
  end

  describe 'factory methods' do
    describe '.new_generic_entry' do
      it 'creates entry with JSON payload' do
        json_message = '{"event": "test", "value": 123, "active": true}'
        entry = LogFlux::LogEntry.new_generic_entry(json_message)
        
        expect(entry.message).to eq(json_message)
        expect(entry.entry_type).to eq(LogFlux::LogEntry::TYPE_LOG)
        expect(entry.labels['payload_type']).to eq(LogFlux::LogEntry::PAYLOAD_TYPE_GENERIC_JSON)
        expect(entry.source).to eq('ruby-sdk')
      end

      it 'handles invalid JSON gracefully' do
        entry = LogFlux::LogEntry.new_generic_entry('not json')
        expect(entry.message).to eq('not json')
        expect(entry.labels['payload_type']).to eq(LogFlux::LogEntry::PAYLOAD_TYPE_GENERIC_JSON)
      end

      it 'handles nil payload' do
        entry = LogFlux::LogEntry.new_generic_entry(nil)
        expect(entry.message).to eq('')
        expect(entry.labels['payload_type']).to eq(LogFlux::LogEntry::PAYLOAD_TYPE_GENERIC_JSON)
      end
    end

    describe '.new_metric_entry' do
      it 'creates metric entry with proper type' do
        metric_data = '{"cpu": 45.2, "memory": 1024, "disk": 75.5}'
        entry = LogFlux::LogEntry.new_metric_entry(metric_data)
        
        expect(entry.message).to eq(metric_data)
        expect(entry.entry_type).to eq(LogFlux::LogEntry::TYPE_METRIC)
        expect(entry.labels['payload_type']).to eq(LogFlux::LogEntry::PAYLOAD_TYPE_METRICS)
        expect(entry.source).to eq('ruby-sdk-metrics')
      end

      it 'handles complex metric data' do
        metric_data = {
          cpu_usage: 45.2,
          memory: { used: 1024, free: 512 },
          network: { in: 1000, out: 500 }
        }.to_json
        
        entry = LogFlux::LogEntry.new_metric_entry(metric_data)
        expect(entry.message).to eq(metric_data)
        expect(entry.entry_type).to eq(LogFlux::LogEntry::TYPE_METRIC)
      end
    end

    describe '.new_syslog_entry' do
      it 'creates syslog entry with proper labels' do
        entry = LogFlux::LogEntry.new_syslog_entry('kernel: Out of memory')
        
        expect(entry.message).to eq('kernel: Out of memory')
        expect(entry.entry_type).to eq(LogFlux::LogEntry::TYPE_LOG)
        expect(entry.labels['payload_type']).to eq(LogFlux::LogEntry::PAYLOAD_TYPE_SYSLOG)
        expect(entry.source).to eq('ruby-sdk-syslog')
      end

      it 'handles multiline syslog messages' do
        multiline = "Line 1\nLine 2\nLine 3"
        entry = LogFlux::LogEntry.new_syslog_entry(multiline)
        
        expect(entry.message).to eq(multiline)
        expect(entry.labels['payload_type']).to eq(LogFlux::LogEntry::PAYLOAD_TYPE_SYSLOG)
      end
    end

    describe '.new_journald_entry' do
      it 'creates journald entry if method exists' do
        if LogFlux::LogEntry.respond_to?(:new_journald_entry)
          entry = LogFlux::LogEntry.new_journald_entry('systemd message')
          expect(entry.labels['payload_type']).to eq(LogFlux::LogEntry::PAYLOAD_TYPE_JOURNALD)
          expect(entry.source).to eq('ruby-sdk-journald')
        else
          skip 'new_journald_entry not implemented'
        end
      end
    end
  end

  describe '#to_h' do
    it 'converts simple entry to hash' do
      entry = LogFlux::LogEntry.new('test message')
      hash = entry.to_h
      
      expect(hash).to be_a(Hash)
      expect(hash[:message]).to eq('test message')
      expect(hash[:source]).to eq('ruby-sdk')
      expect(hash[:level]).to eq(LogFlux::LogEntry::LEVEL_INFO)
      expect(hash[:entry_type]).to eq(LogFlux::LogEntry::TYPE_LOG)
      expect(hash[:id]).to be_a(String)
      expect(hash[:timestamp]).to be_a(String)
      expect(hash[:labels]).to eq({})
    end

    it 'includes all fields in hash' do
      entry = LogFlux::LogEntry.new('complex message')
        .with_source('test-source')
        .with_level(LogFlux::LogEntry::LEVEL_ERROR)
        .with_label('env', 'production')
        .with_label('version', '2.0.0')

      hash = entry.to_h
      
      expect(hash[:message]).to eq('complex message')
      expect(hash[:source]).to eq('test-source')
      expect(hash[:level]).to eq(LogFlux::LogEntry::LEVEL_ERROR)
      expect(hash[:labels]).to eq({
        'env' => 'production',
        'version' => '2.0.0'
      })
    end

    it 'creates deep copy of labels' do
      entry = LogFlux::LogEntry.new('test')
        .with_label('key', 'value')
      
      hash = entry.to_h
      hash[:labels]['new_key'] = 'new_value'
      
      expect(entry.labels).to eq({ 'key' => 'value' })
      expect(entry.labels).not_to have_key('new_key')
    end
  end

  describe '#to_json' do
    it 'converts to valid JSON string' do
      entry = LogFlux::LogEntry.new('test message')
      json_string = entry.to_json
      
      expect(json_string).to be_a(String)
      expect { JSON.parse(json_string) }.not_to raise_error
    end

    it 'includes all fields in JSON' do
      entry = LogFlux::LogEntry.new('json test')
        .with_source('json-source')
        .with_level(LogFlux::LogEntry::LEVEL_WARN)
        .with_label('json', 'true')

      json_string = entry.to_json
      parsed = JSON.parse(json_string)
      
      expect(parsed['message']).to eq('json test')
      expect(parsed['source']).to eq('json-source')
      expect(parsed['level']).to eq(LogFlux::LogEntry::LEVEL_WARN)
      expect(parsed['entry_type']).to eq(LogFlux::LogEntry::TYPE_LOG)
      expect(parsed['labels']).to eq({ 'json' => 'true' })
      expect(parsed).to have_key('id')
      expect(parsed).to have_key('timestamp')
    end

    it 'handles special characters in JSON' do
      entry = LogFlux::LogEntry.new('Message with "quotes" and \backslash')
        .with_label('special', "Line 1\nLine 2\tTabbed")
      
      json_string = entry.to_json
      parsed = JSON.parse(json_string)
      
      expect(parsed['message']).to eq('Message with "quotes" and \backslash')
      expect(parsed['labels']['special']).to eq("Line 1\nLine 2\tTabbed")
    end

    it 'handles unicode characters' do
      entry = LogFlux::LogEntry.new('Hello 世界 🌍')
        .with_label('unicode', '测试 émoji 🚀')
      
      json_string = entry.to_json
      parsed = JSON.parse(json_string)
      
      expect(parsed['message']).to eq('Hello 世界 🌍')
      expect(parsed['labels']['unicode']).to eq('测试 émoji 🚀')
    end

    it 'produces consistent JSON format' do
      entry = LogFlux::LogEntry.new('test')
      json1 = entry.to_json
      json2 = entry.to_json
      
      expect(json1).to eq(json2)
    end
  end

  describe 'edge cases and error handling' do
    it 'handles very long messages' do
      long_message = 'A' * 10_000
      entry = LogFlux::LogEntry.new(long_message)
      
      expect(entry.message).to eq(long_message)
      expect(entry.to_json).to include(long_message)
    end

    it 'handles many labels' do
      entry = LogFlux::LogEntry.new('test')
      
      100.times do |i|
        entry.with_label("key_#{i}", "value_#{i}")
      end
      
      expect(entry.labels.size).to eq(100)
      hash = entry.to_h
      expect(hash[:labels].size).to eq(100)
    end

    it 'handles empty strings' do
      entry = LogFlux::LogEntry.new('')
        .with_source('')
        .with_label('', '')
      
      expect(entry.message).to eq('')
      expect(entry.source).to eq('')
      expect(entry.labels).to eq({ '' => '' })
    end

    it 'is thread-safe for reading' do
      entry = LogFlux::LogEntry.new('thread test')
        .with_label('thread', 'safe')
      
      results = []
      threads = 10.times.map do
        Thread.new do
          100.times do
            results << entry.to_json
          end
        end
      end
      
      threads.each(&:join)
      expect(results.size).to eq(1000)
      expect(results.uniq.size).to eq(1) # All JSON outputs should be identical
    end
  end

  describe 'shared examples' do
    subject { LogFlux::LogEntry.new('shared example test') }
    
    it_behaves_like 'a serializable object'
    
    it_behaves_like 'a chainable builder', :with_source
    it_behaves_like 'a chainable builder', :with_level
  end

  describe 'performance characteristics' do
    it 'creates entries efficiently' do
      start_time = Time.now
      1000.times { LogFlux::LogEntry.new('performance test') }
      elapsed = Time.now - start_time
      
      expect(elapsed).to be < 0.1 # Should create 1000 entries in less than 100ms
    end

    it 'serializes to JSON efficiently' do
      entries = 100.times.map { |i| LogFlux::LogEntry.new("Message #{i}") }
      
      start_time = Time.now
      entries.each(&:to_json)
      elapsed = Time.now - start_time
      
      expect(elapsed).to be < 0.05 # Should serialize 100 entries in less than 50ms
    end
  end
end