# -*- encoding : utf-8 -*-

module RabbitJobs

  def self.configure(&block)
    @@configuration ||= Configuration.new
    block.call(@@configuration)
  end

  def self.config
    @@configuration ||= load_config
  end

  def self.load_config
    self.configure do |c|
      c.host 'localhost'
    end
    @@configuration
  end

  class Configuration
    # DEFAULT_PARAMS = {
    #   host: 'localhost',
    #   exchange: 'rabbit_jobs',
    #   queue: {
    #     auto_delete: true,
    #     ack: true
    #     # auto_delete: false,
    #     # ack: true,
    #     # durable: true,
    #     # arguments: {'x-ha-policy' => 'all'}
    #   },
    #   # exchange: {
    #   #   durable: true,
    #   #   auto_delete: false
    #   # },
    # }

    DEFAULT_QUEUE_PARAMS = {
      auto_delete: true,
      ack: true,
      # durable: true,
      # arguments: {'x-ha-policy' => 'all'}
    }

    def to_hash
      @data.dup
    end

    def initialize
      @data = {
        host: 'localhost',
        exchange: 'rabbit_jobs',
        exchange_params: {
          auto_delete: true,
          durable: false
        },
        queues: {}
      }
    end

    def inspect
      @data.inspect
    end

    def [](name)
      @data[name]
    end

    def []=(name, value)
      @data[name] = value
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
      raise ArgumentError.new("name is #{name}.inspect") unless name && name.is_a?(String) && name != ""
      raise ArgumentError.new("params is #{params}.inspect") unless params && params.is_a?(Hash)

      if @data[:queues][name]
        @data[:queues][name].merge!(params)
      else
        @data[:queues][name] = (params == {} ? DEFAULT_QUEUE_PARAMS : params)
      end
    end

    def queues
      @data[:queues].keys
    end

    def queue_name(routing_key)
      [@data[:exchange], routing_key].join('#')
    end

    def publish_params
      {
        persistent: true,
        nowait: false,
        # immediate: true
      }
    end
  end
end