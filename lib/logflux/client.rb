# frozen_string_literal: true

require 'socket'
require 'json'

module LogFlux
  # LogFlux Agent client for Ruby applications
  class Client
    attr_reader :socket_path, :host, :port, :connected

    def initialize(socket_path_or_host, port = nil)
      if port.nil?
        # Unix socket
        @socket_path = socket_path_or_host
        @host = nil
        @port = nil
        @is_unix_socket = true
      else
        # TCP socket
        @socket_path = nil
        @host = socket_path_or_host
        @port = port
        @is_unix_socket = false
      end

      @socket = nil
      @connected = false
    end

    # Factory methods
    def self.unix_client(socket_path)
      new(socket_path)
    end

    def self.tcp_client(host, port)
      new(host, port)
    end

    # Connect to the LogFlux agent
    def connect
      return if @connected

      begin
        @socket = if @is_unix_socket
                    UNIXSocket.new(@socket_path)
                  else
                    TCPSocket.new(@host, @port)
                  end

        @connected = true
      rescue StandardError => e
        cleanup
        raise ConnectionError, "Failed to connect to LogFlux agent: #{e.message}"
      end
    end

    # Send a log entry to the agent
    def send_log_entry(entry)
      raise ConnectionError, 'Client not connected. Call connect first.' unless @connected

      begin
        # Convert entry to JSON
        message_hash = entry.to_h
        json_message = JSON.generate(message_hash)

        # Add newline delimiter
        message_with_newline = "#{json_message}\n"

        # Send the message
        @socket.write(message_with_newline)
        @socket.flush
      rescue StandardError => e
        @connected = false
        cleanup
        raise ConnectionError, "Failed to send log entry: #{e.message}"
      end
    end

    # Check if client is connected
    def connected?
      @connected && @socket && !@socket.closed?
    end

    # Close the connection
    def close
      @connected = false
      cleanup
    end

    # Ensure cleanup on garbage collection
    def finalize
      close
    end

    private

    def cleanup
      return unless @socket

      begin
        @socket.close unless @socket.closed?
      rescue StandardError
        # Ignore errors during cleanup
      ensure
        @socket = nil
      end
    end

    # Custom error class
    class ConnectionError < StandardError; end
  end
end