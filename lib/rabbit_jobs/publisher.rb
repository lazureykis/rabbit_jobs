# -*- encoding : utf-8 -*-

require 'json'
require 'amqp'
require 'eventmachine'

module RabbitJobs
  module Publisher
    extend self
    extend AmqpHelpers

    def enqueue(klass, *params)
      key = RabbitJobs.config.routing_keys.first
      enqueue_to(key, klass, *params)
    end

    def enqueue_to(routing_key, klass, *params)
      raise ArgumentError unless klass && routing_key

      job = klass.new(*params)

      publish_job_to(routing_key, job)
    end

    def publish_job_to(routing_key, job)
      amqp_with_exchange do |connection, exchange|

        queue = make_queue(exchange, routing_key)

        exchange.publish(job.payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({routing_key: routing_key})) {
          connection.close { EM.stop }
        }
      end
    end

    def purge_queue(routing_key)
      raise ArgumentError unless routing_key

      amqp_with_queue(routing_key) do |connection, queue|
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