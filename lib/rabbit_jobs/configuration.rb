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
      c.exchange 'rabbit_jobs', auto_delete: true
      c.queue 'default', auto_delete: true, ack: true
    end
    @@configuration
  end

  class Configuration
    include Helpers

    DEFAULT_QUEUE_PARAMS = {
      auto_delete: true,
      ack: true
    }

    def to_hash
      @data.dup
    end

    def initialize
      @data = {
        host: 'localhost',
        exchange: 'rabbit_jobs',
        exchange_params: {},
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
        @data[:exchange] = value
        if params
          @data[:exchange_params] = params
        end
      else
        @data[:exchange]
      end
    end

    def queue(name, params = {})
      raise ArgumentError.new("name is #{name.inspect}") unless name && name.is_a?(String) && name != ""
      raise ArgumentError.new("params is #{params.inspect}") unless params && params.is_a?(Hash)

      if @data[:queues][name]
        @data[:queues][name].merge!(params)
      else
        @data[:queues][name] = (params == {} ? DEFAULT_QUEUE_PARAMS : params)
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

    def publish_params
      {
        persistent: true,
        nowait: false,
        # immediate: true
      }
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