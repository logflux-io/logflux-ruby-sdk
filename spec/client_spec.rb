require_relative '../lib/logflux/client'
require 'socket'
require 'json'
require 'tempfile'

RSpec.describe LogFlux::Client do
  let(:unix_socket_path) { '/tmp/test-logflux.sock' }
  let(:tcp_host) { 'localhost' }
  let(:tcp_port) { 8080 }
  let(:shared_secret) { 'test-secret-123' }

  describe '#initialize' do
    context 'with Unix socket configuration' do
      subject { described_class.new(unix_socket: unix_socket_path) }
      
      it 'creates a client with Unix socket config' do
        expect(subject.instance_variable_get(:@config)[:type]).to eq(:unix)
        expect(subject.instance_variable_get(:@config)[:unix_socket]).to eq(unix_socket_path)
      end

      it 'sets default timeout' do
        config = subject.instance_variable_get(:@config)
        expect(config[:timeout]).to eq(5)
      end

      it 'sets default retry count' do
        config = subject.instance_variable_get(:@config)
        expect(config[:max_retries]).to eq(3)
      end

      it 'accepts custom timeout' do
        client = described_class.new(unix_socket: unix_socket_path, timeout: 10)
        expect(client.instance_variable_get(:@config)[:timeout]).to eq(10)
      end
    end

    context 'with TCP configuration' do
      subject { described_class.new(host: tcp_host, port: tcp_port) }
      
      it 'creates a client with TCP config' do
        expect(subject.instance_variable_get(:@config)[:type]).to eq(:tcp)
        expect(subject.instance_variable_get(:@config)[:host]).to eq(tcp_host)
        expect(subject.instance_variable_get(:@config)[:port]).to eq(tcp_port)
      end

      it 'handles string port numbers' do
        client = described_class.new(host: tcp_host, port: '8080')
        expect(client.instance_variable_get(:@config)[:port]).to eq(8080)
      end

      it 'validates port range' do
        expect { described_class.new(host: tcp_host, port: 0) }
          .to raise_error(ArgumentError, /Invalid port/)
        expect { described_class.new(host: tcp_host, port: 65536) }
          .to raise_error(ArgumentError, /Invalid port/)
      end
    end

    context 'with authentication' do
      subject { described_class.new(host: tcp_host, port: tcp_port, shared_secret: shared_secret) }
      
      it 'stores authentication configuration' do
        expect(subject.instance_variable_get(:@config)[:shared_secret]).to eq(shared_secret)
      end

      it 'requires auth for TCP connections' do
        expect(subject.instance_variable_get(:@config)[:auth_required]).to eq(true)
      end

      it 'does not require auth for Unix sockets' do
        client = described_class.new(unix_socket: unix_socket_path, shared_secret: shared_secret)
        expect(client.instance_variable_get(:@config)[:auth_required]).to eq(false)
      end
    end

    context 'with invalid configuration' do
      it 'raises error for missing connection details' do
        expect { described_class.new }.to raise_error(ArgumentError, /connection type/)
      end

      it 'raises error for both Unix and TCP specified' do
        expect { described_class.new(unix_socket: unix_socket_path, host: tcp_host, port: tcp_port) }
          .to raise_error(ArgumentError, /both Unix socket and TCP/)
      end

      it 'raises error for TCP without port' do
        expect { described_class.new(host: tcp_host) }
          .to raise_error(ArgumentError, /TCP host requires port/)
      end

      it 'raises error for invalid host' do
        expect { described_class.new(host: '', port: tcp_port) }
          .to raise_error(ArgumentError, /Invalid host/)
      end
    end

    context 'with additional options' do
      it 'accepts batch size configuration' do
        client = described_class.new(unix_socket: unix_socket_path, batch_size: 100)
        expect(client.instance_variable_get(:@config)[:batch_size]).to eq(100)
      end

      it 'accepts retry delay configuration' do
        client = described_class.new(unix_socket: unix_socket_path, retry_delay: 2)
        expect(client.instance_variable_get(:@config)[:retry_delay]).to eq(2)
      end

      it 'accepts buffer size configuration' do
        client = described_class.new(unix_socket: unix_socket_path, buffer_size: 8192)
        expect(client.instance_variable_get(:@config)[:buffer_size]).to eq(8192)
      end
    end
  end

  describe '#send_log' do
    let(:client) { described_class.new(unix_socket: unix_socket_path) }
    let(:log_entry) { sample_log_entry("Test log message") }

    it 'accepts a LogEntry object' do
      allow(client).to receive(:connect_and_send).and_return(true)
      
      expect { client.send_log(log_entry) }.not_to raise_error
      expect(client).to have_received(:connect_and_send)
    end

    it 'accepts a string message' do
      allow(client).to receive(:connect_and_send).and_return(true)
      
      expect { client.send_log("Simple string message") }.not_to raise_error
      expect(client).to have_received(:connect_and_send)
    end

    it 'accepts a hash and converts to JSON' do
      allow(client).to receive(:connect_and_send).and_return(true)
      
      hash_log = { event: 'test', value: 123 }
      expect { client.send_log(hash_log) }.not_to raise_error
      expect(client).to have_received(:connect_and_send)
    end

    it 'raises error for invalid input' do
      expect { client.send_log(nil) }.to raise_error(ArgumentError, /Cannot send nil/)
      expect { client.send_log(123) }.to raise_error(ArgumentError, /Unsupported log type/)
    end

    it 'handles connection errors with retries' do
      allow(client).to receive(:connect_and_send)
        .and_raise(Errno::ECONNREFUSED)
      
      expect { client.send_log("test") }.to raise_error(LogFlux::ConnectionError)
    end

    it 'returns true on successful send' do
      allow(client).to receive(:connect_and_send).and_return(true)
      
      result = client.send_log("test message")
      expect(result).to eq(true)
    end
  end

  describe '#send_batch' do
    let(:client) { described_class.new(unix_socket: unix_socket_path) }
    let(:log_entries) { sample_entries(3) }

    it 'accepts an array of LogEntry objects' do
      allow(client).to receive(:connect_and_send).and_return(true)
      
      expect { client.send_batch(log_entries) }.not_to raise_error
      expect(client).to have_received(:connect_and_send)
    end

    it 'accepts an array of strings' do
      allow(client).to receive(:connect_and_send).and_return(true)
      
      string_messages = ["Message 1", "Message 2", "Message 3"]
      expect { client.send_batch(string_messages) }.not_to raise_error
      expect(client).to have_received(:connect_and_send)
    end

    it 'accepts mixed array of entries and strings' do
      allow(client).to receive(:connect_and_send).and_return(true)
      
      mixed_batch = [
        sample_log_entry("LogEntry message"),
        "String message",
        { event: 'hash', value: 42 }
      ]
      expect { client.send_batch(mixed_batch) }.not_to raise_error
      expect(client).to have_received(:connect_and_send)
    end

    it 'raises error for empty batch' do
      expect { client.send_batch([]) }.to raise_error(ArgumentError, /empty batch/)
    end

    it 'raises error for non-array input' do
      expect { client.send_batch("not an array") }.to raise_error(ArgumentError, /must be an array/)
    end

    it 'raises error for nil batch' do
      expect { client.send_batch(nil) }.to raise_error(ArgumentError, /must be an array/)
    end

    it 'handles large batches by splitting' do
      client = described_class.new(unix_socket: unix_socket_path, batch_size: 2)
      allow(client).to receive(:connect_and_send).and_return(true)
      
      large_batch = sample_entries(5)
      client.send_batch(large_batch)
      
      # Should be called 3 times (2+2+1)
      expect(client).to have_received(:connect_and_send).exactly(3).times
    end

    it 'returns true on successful batch send' do
      allow(client).to receive(:connect_and_send).and_return(true)
      
      result = client.send_batch(log_entries)
      expect(result).to eq(true)
    end
  end

  describe 'connection handling' do
    let(:client) { described_class.new(unix_socket: unix_socket_path) }

    it 'includes timeout configuration' do
      config = client.instance_variable_get(:@config)
      expect(config).to have_key(:timeout)
      expect(config[:timeout]).to be > 0
    end

    it 'includes retry configuration' do
      config = client.instance_variable_get(:@config)
      expect(config).to have_key(:max_retries)
      expect(config[:max_retries]).to be >= 0
    end

    it 'retries on connection failure' do
      client = described_class.new(unix_socket: unix_socket_path, max_retries: 2)
      attempt_count = 0
      
      allow(client).to receive(:connect_and_send) do
        attempt_count += 1
        if attempt_count < 3
          raise Errno::ECONNREFUSED
        else
          true
        end
      end
      
      result = client.send_log("test")
      expect(result).to eq(true)
      expect(attempt_count).to eq(3)
    end

    it 'respects retry delay' do
      client = described_class.new(unix_socket: unix_socket_path, max_retries: 1, retry_delay: 0.1)
      allow(client).to receive(:connect_and_send).and_raise(Errno::ECONNREFUSED)
      
      start_time = Time.now
      expect { client.send_log("test") }.to raise_error(LogFlux::ConnectionError)
      elapsed = Time.now - start_time
      
      expect(elapsed).to be >= 0.1
    end
  end

  describe 'authentication handling' do
    context 'with TCP and shared secret' do
      let(:client) { described_class.new(host: tcp_host, port: tcp_port, shared_secret: shared_secret) }
      
      it 'sends authentication on connect' do
        allow(client).to receive(:connect_and_send) do |data|
          parsed = JSON.parse(data)
          expect(parsed).to have_key('auth')
          expect(parsed['auth']).to eq(shared_secret)
          true
        end
        
        client.send_log("test message")
      end
    end

    context 'with Unix socket' do
      let(:client) { described_class.new(unix_socket: unix_socket_path, shared_secret: shared_secret) }
      
      it 'does not send authentication' do
        allow(client).to receive(:connect_and_send) do |data|
          parsed = JSON.parse(data)
          expect(parsed).not_to have_key('auth')
          true
        end
        
        client.send_log("test message")
      end
    end
  end

  describe 'error handling' do
    let(:client) { described_class.new(unix_socket: unix_socket_path) }
    
    it 'handles socket errors gracefully' do
      allow(client).to receive(:connect_and_send).and_raise(SocketError, "getaddrinfo: Name or service not known")
      
      expect { client.send_log("test") }.to raise_error(LogFlux::ConnectionError, /Socket error/)
    end

    it 'handles timeout errors' do
      allow(client).to receive(:connect_and_send).and_raise(Timeout::Error)
      
      expect { client.send_log("test") }.to raise_error(LogFlux::ConnectionError, /Connection timeout/)
    end

    it 'handles IO errors' do
      allow(client).to receive(:connect_and_send).and_raise(IOError, "closed stream")
      
      expect { client.send_log("test") }.to raise_error(LogFlux::ConnectionError, /IO error/)
    end

    it 'handles system call errors' do
      allow(client).to receive(:connect_and_send).and_raise(SystemCallError.new("Operation not permitted", 1))
      
      expect { client.send_log("test") }.to raise_error(LogFlux::ConnectionError, /System error/)
    end

    it 'provides detailed error messages' do
      allow(client).to receive(:connect_and_send).and_raise(Errno::ECONNREFUSED)
      
      begin
        client.send_log("test")
      rescue LogFlux::ConnectionError => e
        expect(e.message).to include("Connection refused")
        expect(e.message).to include(unix_socket_path)
      end
    end
  end

  describe 'performance characteristics' do
    let(:client) { described_class.new(unix_socket: unix_socket_path) }
    
    it 'creates clients efficiently' do
      start_time = Time.now
      100.times { described_class.new(unix_socket: unix_socket_path) }
      elapsed = Time.now - start_time
      
      expect(elapsed).to be < 0.01 # Should create 100 clients in less than 10ms
    end

    it 'prepares log data efficiently' do
      allow(client).to receive(:connect_and_send).and_return(true)
      
      entries = sample_entries(100)
      start_time = Time.now
      client.send_batch(entries)
      elapsed = Time.now - start_time
      
      expect(elapsed).to be < 0.1 # Should process 100 entries in less than 100ms
    end
  end

  describe 'data formatting' do
    let(:client) { described_class.new(unix_socket: unix_socket_path) }
    
    it 'formats LogEntry correctly' do
      entry = sample_log_entry("Test message")
      allow(client).to receive(:connect_and_send) do |data|
        parsed = JSON.parse(data)
        expect(parsed['message']).to eq("Test message")
        expect(parsed).to have_key('id')
        expect(parsed).to have_key('timestamp')
        expect(parsed).to have_key('source')
        true
      end
      
      client.send_log(entry)
    end

    it 'formats string messages correctly' do
      allow(client).to receive(:connect_and_send) do |data|
        parsed = JSON.parse(data)
        expect(parsed['message']).to eq("Plain text message")
        expect(parsed['source']).to eq('ruby-sdk')
        true
      end
      
      client.send_log("Plain text message")
    end

    it 'preserves unicode in messages' do
      unicode_msg = "Hello 世界 🌍"
      allow(client).to receive(:connect_and_send) do |data|
        parsed = JSON.parse(data)
        expect(parsed['message']).to eq(unicode_msg)
        true
      end
      
      client.send_log(unicode_msg)
    end
  end

  describe 'thread safety' do
    let(:client) { described_class.new(unix_socket: unix_socket_path) }
    
    it 'handles concurrent sends' do
      allow(client).to receive(:connect_and_send).and_return(true)
      
      threads = []
      errors = []
      
      10.times do |i|
        threads << Thread.new do
          begin
            client.send_log("Thread #{i} message")
          rescue => e
            errors << e
          end
        end
      end
      
      threads.each(&:join)
      expect(errors).to be_empty
    end
  end

  # Integration test placeholders
  describe 'integration tests', :integration do
    let(:client) { described_class.new(unix_socket: unix_socket_path) }
    
    before(:each) do
      skip "Integration tests require running LogFlux agent"
    end

    it 'connects to real Unix socket'
    it 'connects to real TCP socket'
    it 'sends log successfully'
    it 'handles authentication'
    it 'handles network errors'
    it 'handles agent restarts'
    it 'sends large batches'
    it 'handles concurrent connections'
  end
end