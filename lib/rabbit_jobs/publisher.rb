# -*- encoding : utf-8 -*-

require 'json'
require 'amqp'
require 'eventmachine'

module RabbitJobs
  class Publisher
    def self.enqueue(klass, *params)
      raise ArgumentError unless klass

      host = Configuration.host
      queue_name = Configuration.queue_name
      queue_params = Configuration.queue_params
      exchange_name = Configuration.exchange_name
      exchange_params = Configuration.exchange_params
      publish_params = Configuration.publish_params
      routing_key = Configuration.routing_key

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