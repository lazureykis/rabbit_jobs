# -*- encoding : utf-8 -*-

require 'json'
require 'amqp'
require 'eventmachine'

module RabbitJobs
  class Publisher
    def self.enqueue(klass, *params)
      raise ArgumentError unless klass

      host = Configuration.host
      queue_name = Configuration.queue[:name]
      queue_params = Configuration.queue[:params]

      message_text = ([klass.to_s] + params).to_json

      AMQP.start(host: host) do |connection|
        channel  = AMQP::Channel.new(connection)
        queue    = channel.queue(queue_name, queue_params)
        exchange = channel.default_exchange

        exchange.publish(message_text, :routing_key => queue.name) {
          connection.close {
            EM.stop
          }
        }
      end
    end
  end
end