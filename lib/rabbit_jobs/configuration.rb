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
        c.prefix 'rabbit_jobs'
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
        workers: {},
        servers: [],
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

    def servers(*value)
      unless value.empty?
        @data[:servers] = value.map(&:to_s).map(&:strip).keep_if{|url|!url.empty?}.map {|url|
          normalize_url(url)
        }
      end
      @data[:servers]
    end

    def server(value = nil)
      raise unless value && !value.to_s.empty?
      value = normalize_url(value.to_s.strip)
      @data[:servers] ||= []
      @data[:servers] << value unless @data[:servers].include?(value)
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

      name = name.downcase.to_sym

      if @data[:queues][name]
        @data[:queues][name].merge!(params)
      else
        @data[:queues][name] = DEFAULT_QUEUE_PARAMS.merge(params)
      end
    end

    def workers
      @data[:workers] ||= {}
    end

    def worker(name, params = {})
      raise ArgumentError.new("name is #{name.inspect}") unless name && name.is_a?(String) && name != ""
      raise ArgumentError.new("params is #{params.inspect}") unless params && params.is_a?(Hash)
      raise ArgumentError.new("params should have :instances and :queues keys.") unless params[:instances] && params[:queues]

      name = name.downcase.to_sym

      @data[:workers] ||= {}
      if @data[:workers][name]
        @data[:workers][name].merge!(params)
      else
        @data[:workers][name] = params
      end
    end

    def routing_keys
      @data[:queues].keys
    end

    def init_default_queue
      queue('default', DEFAULT_QUEUE_PARAMS) if @data[:queues].empty?
    end

    def worker_queues
      @data[:workers].values.map{|w| w[:queues].to_s.split(' ')}.flatten.uniq.sort
    end

    def default_queue
      queue('default', DEFAULT_QUEUE_PARAMS) if @data[:queues].empty?
      worker_queues.first
    end

    def queue_name(routing_key)
      routing_key = routing_key.to_sym
      @data[:queues][routing_key][:ignore_prefix] ? routing_key : [@data[:prefix], routing_key].compact.join('#')
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
        @data = {prefix: nil, queues: {}}
        %w(prefix mail_errors_to mail_errors_from).each do |m|
          self.send(m, yaml[m])
        end
        yaml['servers'].split(",").each do |value|
          server normalize_url(value)
        end
        yaml['queues'].each do |name, params|
          queue name, symbolize_keys!(params) || {}
        end

        yaml['workers'].each do |name, params|
          worker name, symbolize_keys!(params) || {}
        end
      end
    end

    private

    def normalize_url(url_string)
      uri = URI.parse(url_string)
      uri.path = "" if uri.path.to_s == "/"
      uri.to_s
    end
  end
end
