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
      c.lock_with :redis, namespace: 'rj', timeout: 30*60 # lock jobs for 30 minutes
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
        host: 'localhost',
        exchange: 'rabbit_jobs',
        exchange_params: DEFAULT_EXCHANGE_PARAMS,
        queues: {}
      }
    end

    def [](name)
      @data[name]
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

    def lock_with(name, params = {})
      raise ArgumentError.new("name is #{name.inspect}") unless name && name.is_a?(Symbol)
      raise ArgumentError.new("params is #{params.inspect}") unless params && params.is_a?(Hash)
      raise NotImplemented if name != :redis

      if name
        @data[:lock_with] = :redis
        @data[:redis] = {timeout: params[:timeout] || 30 * 60, namespace: params[:namespace] || 'rj'}
      else
        @data[:lock_with]
      end
    end

    def redis_namespace
      (@data[:redis] && @data[:redis][:namespace]) || 'rj'
    end

    def redis_timeout
      (@data[:redis] && @data[:redis][:timeout]) || 30 * 60
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

        lock_with yaml['lock_with'].to_sym, yaml[yaml['lock_with'].to_s]
      end
    end
  end
end