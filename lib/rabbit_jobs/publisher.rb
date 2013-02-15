# -*- encoding : utf-8 -*-

require 'json'
require 'amqp'
require 'eventmachine'
require 'uri'
require 'active_support'
require 'active_support/core_ext/module'

module RabbitJobs
  module Publisher
    extend self

    mattr_accessor :_connection
    mattr_accessor :_channel

    def amqp_connection
      self._connection ||= AmqpHelper.prepare_connection(self._connection)
    end

    def amqp_channel
      self._channel ||= AmqpHelper.create_channel(self._connection)
    end

    def publish(klass, *params, &block)
      publish_to(RJ.config.default_queue, klass, *params, &block)
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
        amqp_connection

        if ex.size > 0
          AMQP::Exchange.new(self.amqp_channel, :direct, ex[:name].to_s, Configuration::DEFAULT_EXCHANGE_PARAMS.merge(ex[:params] || {})) do |exchange|
            exchange.publish(payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({key: routing_key.to_sym})) do
              yield if block_given?
            end
          end
        else
          self.amqp_channel.default_exchange.publish(payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({key: routing_key.to_sym})) do
            yield if block_given?
          end
        end
      rescue
        RJ.logger.warn $!.message
        RJ.logger.warn $!.backtrace.join("\n")
        raise $!
      end

      true
    end

    def purge_queue(*routing_keys, &block)
      raise ArgumentError unless routing_keys && routing_keys.count > 0

      messages_count = 0
      count = routing_keys.count

      routing_keys.map(&:to_sym).each do |routing_key|
        queue_name = RJ.config.queue_name(routing_key)
        self.amqp_channel.queue(queue_name, RJ.config[:queues][routing_key]) do |queue, declare_ok|
          queue.status do |messages, consumers|
            queue.purge do |ret|
              RJ.logger.error "Cannot purge queue #{queue_name}." unless ret.is_a?(AMQ::Protocol::Queue::PurgeOk)
              messages_count += ret.message_count
              count -= 1
              if count == 0
                yield(messages_count) if block_given?
              end
            end
          end
        end
      end

      messages_count
    end
  end
end