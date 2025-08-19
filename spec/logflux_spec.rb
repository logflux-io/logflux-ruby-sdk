require_relative '../lib/logflux'

RSpec.describe LogFlux do
  describe 'module constants' do
    it 'has a version number' do
      expect(LogFlux::VERSION).not_to be nil
      expect(LogFlux::VERSION).to match(/^\d+\.\d+\.\d+/)
    end

    it 'exports main classes' do
      expect(LogFlux.const_defined?(:LogEntry)).to eq(true)
      expect(LogFlux.const_defined?(:Client)).to eq(true)
    end

    it 'exports error classes' do
      expect(LogFlux.const_defined?(:Error)).to eq(true)
      expect(LogFlux.const_defined?(:ConnectionError)).to eq(true)
      expect(LogFlux.const_defined?(:ConfigurationError)).to eq(true)
    end
  end

  describe 'module methods' do
    describe '.configure' do
      it 'accepts configuration block if method exists' do
        if LogFlux.respond_to?(:configure)
          expect { 
            LogFlux.configure do |config|
              config.default_source = 'test-app'
            end
          }.not_to raise_error
        else
          skip '.configure not implemented'
        end
      end
    end

    describe '.logger' do
      it 'provides a module-level logger if method exists' do
        if LogFlux.respond_to?(:logger)
          expect(LogFlux.logger).to respond_to(:info)
          expect(LogFlux.logger).to respond_to(:error)
        else
          skip '.logger not implemented'
        end
      end
    end
  end

  describe 'error hierarchy' do
    it 'has a base Error class' do
      expect(LogFlux::Error).to be < StandardError
    end

    it 'has specialized error classes' do
      expect(LogFlux::ConnectionError).to be < LogFlux::Error
      expect(LogFlux::ConfigurationError).to be < LogFlux::Error
    end

    it 'can raise and rescue errors' do
      expect { raise LogFlux::ConnectionError, "Test error" }
        .to raise_error(LogFlux::ConnectionError, "Test error")
      
      expect { raise LogFlux::ConfigurationError, "Config error" }
        .to raise_error(LogFlux::ConfigurationError, "Config error")
    end
  end

  describe 'convenience methods' do
    describe '.create_client' do
      it 'creates a client with Unix socket if method exists' do
        if LogFlux.respond_to?(:create_client)
          client = LogFlux.create_client(unix_socket: '/tmp/test.sock')
          expect(client).to be_a(LogFlux::Client)
        else
          skip '.create_client not implemented'
        end
      end
    end

    describe '.create_entry' do
      it 'creates a log entry if method exists' do
        if LogFlux.respond_to?(:create_entry)
          entry = LogFlux.create_entry('Test message')
          expect(entry).to be_a(LogFlux::LogEntry)
        else
          skip '.create_entry not implemented'
        end
      end
    end
  end

  describe 'usage patterns' do
    it 'supports basic workflow' do
      # Create an entry
      entry = LogFlux::LogEntry.new('Application started')
        .with_source('test-app')
        .with_level(LogFlux::LogEntry::LEVEL_INFO)
        .with_label('environment', 'test')
      
      expect(entry).to be_a(LogFlux::LogEntry)
      expect(entry.message).to eq('Application started')
      
      # Create a client
      client = LogFlux::Client.new(unix_socket: '/tmp/logflux.sock')
      expect(client).to be_a(LogFlux::Client)
    end

    it 'supports batch operations' do
      entries = []
      
      # Create multiple entries
      5.times do |i|
        entries << LogFlux::LogEntry.new("Message #{i}")
          .with_source('batch-test')
          .with_label('batch_id', '12345')
      end
      
      expect(entries.length).to eq(5)
      expect(entries.all? { |e| e.is_a?(LogFlux::LogEntry) }).to eq(true)
    end

    it 'supports metric entries' do
      metric_data = {
        cpu_usage: 45.2,
        memory_mb: 1024,
        disk_usage_percent: 75.5
      }.to_json
      
      entry = LogFlux::LogEntry.new_metric_entry(metric_data)
      
      expect(entry.entry_type).to eq(LogFlux::LogEntry::TYPE_METRIC)
      expect(entry.labels['payload_type']).to eq(LogFlux::LogEntry::PAYLOAD_TYPE_METRICS)
    end

    it 'supports syslog entries' do
      entry = LogFlux::LogEntry.new_syslog_entry('kernel: Out of memory')
      
      expect(entry.labels['payload_type']).to eq(LogFlux::LogEntry::PAYLOAD_TYPE_SYSLOG)
      expect(entry.source).to eq('ruby-sdk-syslog')
    end
  end

  describe 'version compatibility' do
    it 'follows semantic versioning' do
      version_parts = LogFlux::VERSION.split('.')
      expect(version_parts.length).to eq(3)
      
      major, minor, patch = version_parts
      expect(major.to_i).to be >= 0
      expect(minor.to_i).to be >= 0
      expect(patch.to_i).to be >= 0
    end
  end

  describe 'thread safety' do
    it 'can be used from multiple threads' do
      results = []
      errors = []
      mutex = Mutex.new
      
      threads = 5.times.map do |i|
        Thread.new do
          begin
            entry = LogFlux::LogEntry.new("Thread #{i}")
            mutex.synchronize { results << entry }
          rescue => e
            mutex.synchronize { errors << e }
          end
        end
      end
      
      threads.each(&:join)
      
      expect(errors).to be_empty
      expect(results.length).to eq(5)
    end
  end

  describe 'memory management' do
    it 'does not leak memory with repeated entry creation' do
      # This is a basic test - real memory leak detection would require
      # more sophisticated tooling
      
      initial_object_count = ObjectSpace.count_objects[:T_OBJECT]
      
      100.times do
        LogFlux::LogEntry.new('Memory test')
          .with_source('mem-test')
          .with_label('test', 'true')
      end
      
      GC.start
      final_object_count = ObjectSpace.count_objects[:T_OBJECT]
      
      # Allow for some variance but ensure no massive leak
      object_increase = final_object_count - initial_object_count
      expect(object_increase).to be < 1000
    end
  end
end