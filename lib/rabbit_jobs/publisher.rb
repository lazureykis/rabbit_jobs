# -*- encoding : utf-8 -*-

require 'json'
require 'bunny'
require 'uri'
require 'active_support'
require 'active_support/core_ext/module'

module RabbitJobs
  module Publisher
    extend self

    def cleanup
      conn = Thread.current[:rj_publisher_connection]
      conn.close if conn && conn.status != :not_connected
      Thread.current[:rj_publisher_connection] = nil
    end

    def publish_to(routing_key, klass, *params)
      raise ArgumentError.new("klass=#{klass.inspect}") unless klass.is_a?(Class) || klass.is_a?(String)
      routing_key = routing_key.to_sym unless routing_key.is_a?(Symbol)
      raise ArgumentError.new("routing_key=#{routing_key}") unless RabbitJobs.config[:queues][routing_key]

      payload = {
        'class' => klass.to_s,
        'opts' => {'created_at' => Time.now.to_i},
        'params' => params
        }.to_json

      direct_publish_to(RabbitJobs.config.queue_name(routing_key), payload)
    end

    def direct_publish_to(routing_key, payload, ex = {})
      check_connection
      begin
        exchange = get_exchange(ex)
        exchange.publish(payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({key: routing_key.to_sym}))
        # channel.wait_for_confirms
      rescue
        RabbitJobs.logger.warn $!.message
        RabbitJobs.logger.warn $!.backtrace.join("\n")
        raise $!
      end

      true
    end

    def purge_queue(*routing_keys)
      raise ArgumentError unless routing_keys.present?

      messages_count = 0

      routing_keys.map(&:to_sym).each do |routing_key|
        queue_name = RabbitJobs.config.queue_name(routing_key)
        queue = connection.queue(queue_name, RabbitJobs.config[:queues][routing_key])
        messages_count += queue.status[:message_count]
        queue.purge
      end

      messages_count
    end

    private

    def settings
      Thread.current[:rj_publisher] ||= {}
    end

    def connection
      unless settings[:connection]
        settings[:connection] = Bunny.new(RabbitJobs.config.server, :heartbeat_interval => 5)
        settings[:connection].start
        # settings[:channel].confirm_select
      end
      settings[:connection]
    end

    def exchanges
      settings[:exchanges] ||= {}
    end

    def get_exchange(ex = {})
      ex = {name: ex} if ex.is_a?(String)
      raise ArgumentError.new("Need to pass exchange name") if ex.size > 0 && ex[:name].to_s.empty?

      if ex.size > 0
        exchange_opts = Configuration::DEFAULT_EXCHANGE_PARAMS.merge(ex[:params] || {}).merge({type: (ex[:type] || :direct)})
        exchanges[ex[:name]] ||= connection.default_channel.exchange(ex[:name].to_s, exchange_opts)
      else
        exchanges[ex[:name]] ||= connection.default_channel.default_exchange
      end
    end

    def check_connection
      raise unless connection.connected?
    end
  end
end
