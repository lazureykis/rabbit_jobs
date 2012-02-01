# -*- encoding : utf-8 -*-

require 'json'
require 'amqp'
require 'eventmachine'

module RabbitJobs
  module Publisher
    extend self
    extend AmqpHelpers

    def publish(klass, opts = {}, *params)
      key = RabbitJobs.config.routing_keys.first
      publish_to(key, klass, opts, *params)
    end

    def publish_to(routing_key, klass, opts = {}, *params)
      raise ArgumentError unless klass && routing_key
      opts ||= {}

      job = klass.new(*params)
      job.opts = opts

      if defined?(EM) && EM.reactor_running?
        em_publish_job_to(routing_key, job)
      else
        publish_job_to(routing_key, job)
      end
    end

    def publish_job_to(routing_key, job)
      amqp_with_exchange do |connection, exchange|

        queue = make_queue(exchange, routing_key)

        job.opts['created_at'] = Time.now.to_i

        payload = job.payload
        exchange.publish(job.payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({routing_key: routing_key})) {
          connection.close {
            EM.stop
          }
        }
      end
    end

    def em_publish_job_to(routing_key, job)
      em_amqp_with_exchange do |connection, exchange|
        queue = make_queue(exchange, routing_key)

        job.opts['created_at'] = Time.now.to_i

        payload = job.payload
        exchange.publish(job.payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({routing_key: routing_key})) {
          connection.close {
          }
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