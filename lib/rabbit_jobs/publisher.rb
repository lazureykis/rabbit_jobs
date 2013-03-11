# -*- encoding : utf-8 -*-

require 'json'
require 'bunny'
require 'uri'
require 'active_support'
require 'active_support/core_ext/module'

module RabbitJobs
  module Publisher
    extend self

    def amqp_connection
      Thread.current[:rj_publisher_connection] ||= AmqpHelper.prepare_connection
    end

    def cleanup
      conn = Thread.current[:rj_publisher_connection]
      conn.close if conn && conn.status != :not_connected
      Thread.current[:rj_publisher_connection] = nil
    end

    def publish_to(routing_key, klass, *params, &block)
      raise ArgumentError.new("klass=#{klass.inspect}") unless klass && (klass.is_a?(Class) || klass.is_a?(String))
      raise ArgumentError.new("routing_key=#{routing_key}") unless routing_key && (routing_key.is_a?(Symbol) || routing_key.is_a?(String)) && !!RJ.config[:queues][routing_key.to_sym]

      payload = {
        'class' => klass.to_s,
        'opts' => {'created_at' => Time.now.to_i},
        'params' => params
        }.to_json

      direct_publish_to(RJ.config.queue_name(routing_key.to_sym), payload, &block)
    end

    def direct_publish_to(routing_key, payload, ex = {}, &block)
      ex = {name: ex} if ex.is_a?(String)
      raise ArgumentError.new("Need to pass exchange name") if ex.size > 0 && ex[:name].to_s.empty?

      begin
        exchange = if ex.size > 0
          exchange_opts = Configuration::DEFAULT_EXCHANGE_PARAMS.merge(ex[:params] || {}).merge({type: (ex[:type] || :direct)})
          amqp_connection.channel.exchange(ex[:name].to_s, exchange_opts)
        else
          amqp_connection.channel.default_exchange
        end

        exchange.publish(payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({key: routing_key.to_sym}))
      rescue
        RJ.logger.warn $!.message
        RJ.logger.warn $!.backtrace.join("\n")
        raise $!
      end

      yield if block_given?
      true
    end

    def purge_queue(*routing_keys, &block)
      raise ArgumentError unless routing_keys && routing_keys.count > 0

      messages_count = 0
      count = routing_keys.count

      routing_keys.map(&:to_sym).each do |routing_key|
        queue_name = RJ.config.queue_name(routing_key)
        queue = amqp_connection.queue(queue_name, RJ.config[:queues][routing_key])
        messages_count += queue.status[:message_count]
        queue.delete
      end

      yield(messages_count) if block_given?

      messages_count
    end
  end
end
