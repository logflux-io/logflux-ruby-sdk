# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'time'

module LogFlux
  # Represents a log entry to be sent to LogFlux Agent
  class LogEntry
    # Entry Types
    TYPE_LOG = 1
    TYPE_METRIC = 2
    TYPE_TRACE = 3
    TYPE_EVENT = 4
    TYPE_AUDIT = 5

    # Log Levels (syslog)
    LEVEL_EMERGENCY = 0
    LEVEL_ALERT = 1
    LEVEL_CRITICAL = 2
    LEVEL_ERROR = 3
    LEVEL_WARNING = 4
    LEVEL_NOTICE = 5
    LEVEL_INFO = 6
    LEVEL_DEBUG = 7

    # Payload Types
    PAYLOAD_TYPE_SYSTEMD_JOURNAL = 'systemd_journal'
    PAYLOAD_TYPE_SYSLOG = 'syslog'
    PAYLOAD_TYPE_METRICS = 'metrics'
    PAYLOAD_TYPE_APPLICATION = 'application'
    PAYLOAD_TYPE_CONTAINER = 'container'
    PAYLOAD_TYPE_GENERIC = 'generic'
    PAYLOAD_TYPE_GENERIC_JSON = 'generic_json'

    attr_reader :id, :message, :source, :entry_type, :level, :timestamp, :labels

    def initialize(message)
      @id = SecureRandom.uuid
      @message = message
      @source = 'ruby-sdk'
      @entry_type = TYPE_LOG
      @level = LEVEL_INFO
      @timestamp = Time.now.to_i
      @labels = {}
    end

    # Builder pattern methods
    def with_source(source)
      @source = source
      self
    end

    def with_type(entry_type)
      @entry_type = entry_type
      self
    end

    def with_level(level)
      @level = level
      self
    end

    def with_timestamp(timestamp)
      @timestamp = timestamp
      self
    end

    def with_label(key, value)
      @labels[key] = value.to_s
      self
    end

    def with_payload_type(payload_type)
      with_label('payload_type', payload_type)
    end

    # Convenience factory methods
    def self.new_generic_entry(message)
      payload_type = valid_json?(message) ? PAYLOAD_TYPE_GENERIC_JSON : PAYLOAD_TYPE_GENERIC
      new(message).with_payload_type(payload_type)
    end

    def self.new_syslog_entry(message)
      new(message).with_payload_type(PAYLOAD_TYPE_SYSLOG)
    end

    def self.new_systemd_journal_entry(message)
      new(message).with_payload_type(PAYLOAD_TYPE_SYSTEMD_JOURNAL)
    end

    def self.new_metric_entry(message)
      new(message).with_type(TYPE_METRIC).with_payload_type(PAYLOAD_TYPE_METRICS)
    end

    def self.new_application_entry(message)
      new(message).with_payload_type(PAYLOAD_TYPE_APPLICATION)
    end

    def self.new_container_entry(message)
      new(message).with_payload_type(PAYLOAD_TYPE_CONTAINER)
    end

    # JSON validation helper
    def self.valid_json?(str)
      return false if str.nil? || str.strip.empty?

      JSON.parse(str)
      true
    rescue JSON::ParserError
      false
    end

    # Convert to hash for JSON serialization
    def to_h
      {
        id: @id,
        message: @message,
        source: @source,
        entry_type: @entry_type,
        level: @level,
        timestamp: @timestamp,
        labels: @labels
      }
    end

    # Convert to JSON
    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end