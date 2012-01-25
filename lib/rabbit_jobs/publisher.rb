# -*- encoding : utf-8 -*-

require 'json'
require 'amqp'
require 'eventmachine'

module RabbitJobs
  class Publisher
    def self.enqueue(klass, *params)
      key = RabbitJobs.config.routing_keys.first
      enqueue_to(key, klass, *params)
    end

    def self.enqueue_to(routing_key, klass, *params)
      raise ArgumentError unless klass && routing_key

      host = RabbitJobs.config[:host]
      queue_params = RabbitJobs.config[:queues][routing_key]
      queue_name = RabbitJobs.config.queue_name(routing_key)
      exchange_name = RabbitJobs.config[:exchange]
      exchange_params = RabbitJobs.config[:exchange_params]
      publish_params = RabbitJobs.config.publish_params

      payload = ([klass.to_s] + params).to_json

      AMQP.start(host: host) do |connection|
        channel  = AMQP::Channel.new(connection)

        channel.on_error do |ch, channel_close|
          puts "Channel-level error: #{channel_close.reply_text}, shutting down..."
          connection.close { EM.stop }
        end

        exchange = channel.direct(exchange_name, exchange_params)
        queue    = channel.queue(queue_name, queue_params).bind(exchange, :routing_key => routing_key)

        exchange.publish(payload, publish_params.merge({routing_key: routing_key})) {
          connection.close { EM.stop }
        }
      end
    end

    def self.purge_queue(routing_key)
      raise ArgumentError unless routing_key

      queue_params = RabbitJobs.config[:queues][routing_key]
      queue_name = RabbitJobs.config.queue_name(routing_key)
      exchange_name = RabbitJobs.config[:exchange]
      exchange_params = RabbitJobs.config[:exchange_params]
      publish_params = RabbitJobs.config.publish_params

      AMQP.start(host: RabbitJobs.config.host) do |connection|
        channel  = AMQP::Channel.new(connection)

        channel.on_error do |ch, channel_close|
          puts "Channel-level error: #{channel_close.reply_text}, shutting down..."
          connection.close { EM.stop }
        end

        exchange = channel.direct(exchange_name, exchange_params)
        queue    = channel.queue(queue_name, queue_params).bind(exchange, :routing_key => routing_key)

        queue.status do |number_of_messages, number_of_consumers|
          queue.purge {
            connection.close {
              EM.stop
              return number_of_messages
            }
          }
        end
      end
    end
  end
end