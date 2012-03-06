# -*- encoding : utf-8 -*-

require 'json'
require 'amqp'
require 'eventmachine'
require 'bunny'

module RabbitJobs
  module Publisher
    extend self
    extend AmqpHelpers

    def publish(klass, *params)
      key = RJ.config.routing_keys.first
      publish_to(key, klass, *params)
    end

    def publish_to(routing_key, klass, *params)
      raise ArgumentError unless klass && (klass.is_a?(Class) || klass.is_a?(String))
      raise ArgumentError unless routing_key && (routing_key.is_a?(Symbol) || routing_key.is_a?(String))

      begin
        exchange = bunny.exchange(RJ.config[:exchange], RJ.config[:exchange_params])
        queue = bunny.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key.to_s])
        queue.bind(exchange)

        payload = {
          'class' => klass.to_s,
          'opts' => {'created_at' => Time.now.to_i},
          'params' => params
          }.to_json

        exchange.publish(payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({key: routing_key.to_s}))
        bunny.stop
      rescue
        RJ.logger.warn $!.inspect
        RJ.logger.warn $!.backtrace.join("\n")
      end
    end

    def purge_queue(*routing_keys)
      raise ArgumentError unless routing_keys && routing_keys.count > 0

      messages_count = 0
      routing_keys.each do |routing_key|
        queue = bunny.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key.to_s])
        messages_count += queue.status[:message_count]
        queue.purge
      end
      bunny.stop
      return messages_count
    end

    private
    def self.bunny
      @bunny = Bunny.new(host: RJ.config.host, logging: true)
      @bunny.start unless @bunny.status == :connected
      @bunny
    end
  end
end