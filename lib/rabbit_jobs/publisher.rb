# -*- encoding : utf-8 -*-

require 'json'
require 'amqp'
require 'eventmachine'

module RabbitJobs
  class Publisher
    def self.spam_to_test_queues
      host = Configuration.host
      queue_params = Configuration.queue_params
      exchange_name = Configuration.exchange_name
      exchange_params = Configuration.exchange_params
      publish_params = Configuration.publish_params


      AMQP.start(host: host) do |connection|
        channel  = AMQP::Channel.new(connection)

        channel.on_error { |ch, channel_close|
          puts "Channel-level error: #{channel_close.reply_text}, shutting down..."
          connection.close { EM.stop }
        }

        Configuration.queues.each { |routing_key|
          queue_name = Configuration.queue_name(routing_key)

          exchange = channel.direct(exchange_name, exchange_params)
          queue    = channel.queue(queue_name, queue_params).bind(exchange, :routing_key => routing_key)

          i = 0
          100.times {
            i += 1
            message_text = "Message ##{i}"
            exchange.publish(message_text, publish_params.merge({routing_key: routing_key})) {
              connection.close { EM.stop }
            }
          }
        }
      end
    end

    def self.enqueue(klass, *params)
      queue_name = RabbitJobs.config[:queues].first.key
      enqueue(queue_name, klass, params)
    end

    def self.enqueue_to(routing_key, klass, *params)
      raise ArgumentError unless klass

      host = RabbitJobs.config[:host]
      queue_params = RabbitJobs.config[:queues][routing_key]
      queue_name = RabbitJobs.config.queue_name(routing_key)
      exchange_name = RabbitJobs.config[:exchange]
      exchange_params = RabbitJobs.config[:exchange_params]
      publish_params = RabbitJobs.config.publish_params

      message_text = ([klass.to_s] + params).to_json

      AMQP.start(host: host) do |connection|
        channel  = AMQP::Channel.new(connection)

        channel.on_error do |ch, channel_close|
          puts "Channel-level error: #{channel_close.reply_text}, shutting down..."
          connection.close { EM.stop }
        end

        exchange = channel.direct(exchange_name, exchange_params)
        queue    = channel.queue(queue_name, queue_params).bind(exchange, :routing_key => routing_key)

        exchange.publish(message_text, publish_params.merge({routing_key: routing_key})) {
          connection.close { EM.stop }
        }
      end
    end
  end
end