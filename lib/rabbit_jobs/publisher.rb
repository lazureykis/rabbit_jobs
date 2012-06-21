# -*- encoding : utf-8 -*-

require 'json'
require 'amqp'
require 'eventmachine'
require 'bunny'
require 'uri'

module RabbitJobs
  module Publisher
    extend self
    extend AmqpHelpers

    def publish(klass, *params)
      RJ.config.queue('default', RJ::Configuration::DEFAULT_QUEUE_PARAMS) if RJ.config.routing_keys.empty?
      key = RJ.config.routing_keys.first
      publish_to(key, klass, *params)
    end

    def publish_to(routing_key, klass, *params)
      raise ArgumentError unless klass && (klass.is_a?(Class) || klass.is_a?(String))
      raise ArgumentError unless routing_key && (routing_key.is_a?(Symbol) || routing_key.is_a?(String))

      begin
        with_bunny do |bunny|
          exchange = bunny.exchange(RJ.config[:exchange], RJ.config[:exchange_params])
          queue = bunny.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key.to_s])
          queue.bind(exchange, :routing_key => routing_key.to_s)

          payload = {
            'class' => klass.to_s,
            'opts' => {'created_at' => Time.now.to_i},
            'params' => params
            }.to_json

          exchange.publish(payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({key: routing_key.to_s}))
        end
      rescue
        RJ.logger.warn $!.inspect
        RJ.logger.warn $!.backtrace.join("\n")
      end

      true
    end

    def purge_queue(*routing_keys)
      raise ArgumentError unless routing_keys && routing_keys.count > 0

      messages_count = 0
      with_bunny do |bunny|
        routing_keys.each do |routing_key|
          queue = bunny.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key.to_s])
          messages_count += queue.status[:message_count]
          queue.purge
        end
      end
      return messages_count
    end

    private
    def self.with_bunny(&block)
      raise ArgumentError unless block

      # raise RJ.config.connection_options.inspect
      Bunny.run(RJ.config.connection_options.merge({logging: false})) do |bunny|
        block.call(bunny)
      end
    end
  end
end