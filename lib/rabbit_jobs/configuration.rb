# -*- encoding : utf-8 -*-
require 'yaml'

module RabbitJobs

  extend self

  def configure(&block)
    @@configuration ||= Configuration.new
    block.call(@@configuration)
  end

  def config
    @@configuration ||= load_config
  end

  def load_config
    self.configure do |c|
      c.host 'localhost'
      c.exchange 'rabbit_jobs', auto_delete: false, durable: true
      c.queue 'default', auto_delete: false, ack: true, durable: true
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

    DEFAULT_EXCHANGE_PARAMS = {
      auto_delete: false,
      durable: true
    }

    DEFAULT_MESSAGE_PARAMS = {
      persistent: true,
      nowait: false,
      immediate: false
    }

    def to_hash
      @data.dup
    end

    def initialize
      @data = {
        error_log: true,
        host: 'localhost',
        exchange: 'rabbit_jobs',
        exchange_params: DEFAULT_EXCHANGE_PARAMS,
        queues: {}
      }
    end

    def [](name)
      @data[name]
    end

    def error_log
      @data[:error_log]
    end

    def disable_error_log
      @data[:error_log] = false
    end

    def host(value = nil)
      if value
        raise ArgumentError unless value.is_a?(String) && value != ""
        @data[:host] = value.to_s
      else
        @data[:host]
      end
    end

    def exchange(value = nil, params = {})
      if value
        raise ArgumentError unless value.is_a?(String) && value != ""
        @data[:exchange] = value.downcase
        @data[:exchange_params] = DEFAULT_EXCHANGE_PARAMS.merge(params)
      else
        @data[:exchange]
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

    def queue_name(routing_key)
      [@data[:exchange], routing_key].join('#')
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
      else
        @data = {host: nil, exchange: nil, queues: {}}
        host yaml['host']
        exchange yaml['exchange'], symbolize_keys!(yaml['exchange_params'])
        yaml['queues'].each do |name, params|
          queue name, symbolize_keys!(params) || {}
        end
      end
    end
  end
end