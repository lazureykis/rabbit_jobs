# -*- encoding : utf-8 -*-
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
        c.server "amqp://localhost"
      end
    end

    @@configuration
  end

  class Configuration
    include Helpers

    DEFAULT_EXCHANGE_PARAMS = {
      auto_delete: false,
      durable: true
    }

    DEFAULT_QUEUE_PARAMS = {
      auto_delete: false,
      exclusive: false,
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
        server: 'amqp://localhost',
        queues: {}
      }
    end

    def [](name)
      @data[name]
    end

    def default_queue(value = nil)
      if value
        @default_queue = value.to_sym
      else
        @default_queue || RJ.config[:queues].keys.first || :jobs
      end
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

    def server(value = nil)
      @data[:server] = value.to_s.strip if value && value.length > 0
      @data[:server]
    end

    def queue(name, params = {})
      raise ArgumentError.new("name is #{name.inspect}") unless name && name.is_a?(String) && name != ""
      raise ArgumentError.new("params is #{params.inspect}") unless params && params.is_a?(Hash)

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

    def load_file(filename)
      load_yaml(File.read(filename))
    end

    def load_yaml(text)
      convert_yaml_config(YAML.load(text))
    end

    def convert_yaml_config(yaml)
      yaml = parse_environment(yaml)

      @data = {queues: {}}
      %w(server mail_errors_to mail_errors_from default_queue).each do |m|
        self.send(m, yaml[m])
      end
      yaml['queues'].each do |name, params|
        queue name, symbolize_keys!(params) || {}
      end
    end

    private

    def parse_environment(yaml)
      yaml['rabbit_jobs'] ||
      (defined?(Rails) && yaml[Rails.env.to_s]) ||
      yaml
    end
  end
end
