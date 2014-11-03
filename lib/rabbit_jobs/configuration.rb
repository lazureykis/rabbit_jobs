module RabbitJobs
  # Configuration DSL.
  class Configuration
    DEFAULT_EXCHANGE_PARAMS = {
      auto_delete: false,
      durable: true
    }

    DEFAULT_QUEUE_PARAMS = {
      auto_delete: false,
      exclusive: false,
      durable: true,
      manual_ack: true
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
        server: 'amqp://localhost',
        queues: {
          jobs: DEFAULT_QUEUE_PARAMS
        }
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

    def server(value = nil)
      @data[:server] = value.to_s.strip if value && value.length > 0
      @data[:server]
    end

    def queue(name, params = {})
      fail ArgumentError, "name is #{name.inspect}" unless name && name.is_a?(String) && name != ''
      fail ArgumentError, "params is #{params.inspect}" unless params && params.is_a?(Hash)

      name = name.downcase.to_sym

      if @data[:queues][name]
        @data[:queues][name].merge!(params)
      else
        @data[:queues][name] = DEFAULT_QUEUE_PARAMS.merge(params)
      end
    end

    def routing_keys
      @data[:queues].keys
    end

    def queue?(routing_key)
      routing_keys.include?(routing_key.to_sym)
    end

    def load_file(filename)
      load_yaml(File.read(filename))
    end

    def load_yaml(text)
      convert_yaml_config(YAML.load(text))
    end

    def convert_yaml_config(yaml)
      yaml = parse_environment(yaml)

      @data = { queues: {} }
      %w(server).each do |m|
        send(m, yaml[m])
      end
      yaml['queues'].each do |name, params|
        queue name, params.symbolize_keys || {}
      end
    end

    private

    def parse_environment(yaml)
      yaml['rabbit_jobs'] || (defined?(Rails) && yaml[Rails.env.to_s]) || yaml
    end
  end
end
