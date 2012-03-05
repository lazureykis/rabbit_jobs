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
      raise ArgumentError unless klass && routing_key && klass.is_a?(Class) && (routing_key.is_a?(Symbol) || routing_key.is_a?(String))

      job = klass.new(*params)
      job.opts = {'created_at' => Time.now.to_i}

      exchange = bunny.exchange(RJ.config[:exchange], RJ.config[:exchange_params])
      queue = bunny.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key.to_s])
      queue.bind(exchange)

      exchange.publish(job.payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({key: routing_key.to_s}))
    end

    def purge_queue(*routing_keys)
      raise ArgumentError unless routing_keys && routing_keys.count > 0

      messages_count = 0
      routing_keys.each do |routing_key|
        queue = bunny.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key.to_s])
        messages_count += queue.status[:message_count]
        queue.purge
      end
      return messages_count
    end

    private
    def bunny
      @bunny ||= Bunny.new(host: RJ.config.host, logging: false)
      @bunny.start unless @bunny.status == :connected
      @bunny
    end
  end
end