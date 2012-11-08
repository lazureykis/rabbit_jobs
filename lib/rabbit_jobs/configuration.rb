# -*- encoding : utf-8 -*-
require 'yaml'
require 'uri'

module RabbitJobs

  extend self

  def configure
    @@configuration ||= Configuration.new
    yield @@configuration if block_given?
  end

  def config
    @@configuration ||= load_config
  end

  def load_config(config_file = nil)
    @@configuration ||= nil

    config_file ||= defined?(Rails) && Rails.respond_to?(:root) && Rails.root.join('config/rabbit_jobs.yml')
    if config_file
      if File.exists?(config_file)
        @@configuration ||= Configuration.new
        @@configuration.load_file(config_file)
      end
    end

    unless @@configuration
      self.configure do |c|
        c.url 'amqp://localhost'
        c.prefix 'rabbit_jobs'
      end
    end

    @@configuration
  end

  class Configuration
    include Helpers

    DEFAULT_QUEUE_PARAMS = {
      auto_delete: false,
      durable: true,
      ack: true
    }

    DEFAULT_MESSAGE_PARAMS = {
      persistent: true,
      mandatory: true,
      immediate: false
    }

    def to_hash
      @data.dup
    end

    def initialize
      @data = {
        error_log: true,
        url: 'amqp://localhost',
        prefix: 'rabbit_jobs',
        queues: {}
      }
    end

    def [](name)
      @data[name]
    end

    def mail_errors_to(email = nil)
      if email
        @data[:mail_errors_to] = email
      else
        @data[:mail_errors_to]
      end
    end

    def mail_errors_from(email = nil)
      if email
        @data[:mail_errors_from] = email
      else
        @data[:mail_errors_from]
      end
    end

    def error_log
      @data[:error_log]
    end

    def disable_error_log
      @data[:error_log] = false
    end

    def url(value = nil)
      if value
        raise ArgumentError unless value.is_a?(String) && value != ""
        @data[:url] = value.to_s
        @data.delete :connection_options
      else
        @data[:url] || 'amqp://localhost'
      end
    end

    def prefix(value = nil)
      if value
        raise ArgumentError unless value.is_a?(String) && value != ""
        @data[:prefix] = value.downcase
      else
        @data[:prefix]
      end
    end

    def queue(name, params = {})
      raise ArgumentError.new("name is #{name.inspect}") unless name && name.is_a?(String) && name != ""
      raise ArgumentError.new("params is #{params.inspect}") unless params && params.is_a?(Hash)

      name = name.downcase

      if @data[:queues][name]
        @data[:queues][name].merge!(params)
      else
        @data[:queues][name] = DEFAULT_QUEUE_PARAMS.merge(params)
      end
    end

    def routing_keys
      @data[:queues].keys
    end

    def init_default_queue
      queue('default', DEFAULT_QUEUE_PARAMS) if @data[:queues].empty?
    end

    def default_queue
      queue('default', DEFAULT_QUEUE_PARAMS) if @data[:queues].empty?
      key = @data[:queues].keys.first
    end

    def queue_name(routing_key)
      [@data[:prefix], routing_key].join('#')
    end

    def load_file(filename)
      load_yaml(File.read(filename))
    end

    def load_yaml(text)
      convert_yaml_config(YAML.load(text))
    end

    def convert_yaml_config(yaml)
      if yaml['rabbit_jobs']
        convert_yaml_config(yaml['rabbit_jobs'])
      elsif defined?(Rails) && yaml[Rails.env.to_s]
        convert_yaml_config(yaml[Rails.env.to_s])
      else
        @data = {url: nil, prefix: nil, queues: {}}
        %w(url prefix mail_errors_to mail_errors_from).each do |m|
          self.send(m, yaml[m])
        end
        yaml['queues'].each do |name, params|
          queue name, symbolize_keys!(params) || {}
        end
      end
    end
  end
end