# -*- encoding : utf-8 -*-

require 'json'
require 'amqp'
require 'eventmachine'

module RabbitJobs
  module Publisher
    extend self
    extend AmqpHelpers

    def publish(klass, opts = {}, *params)
      key = RJ.config.routing_keys.first
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

        queue = make_queue(exchange, routing_key.to_s)

        job.opts['created_at'] = Time.now.to_i

        payload = job.payload
        exchange.publish(job.payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({routing_key: routing_key.to_s})) {
          connection.close {
            EM.stop
          }
        }
      end
    end

    def em_publish_job_to(routing_key, job)
      em_amqp_with_exchange do |connection, exchange|
        queue = make_queue(exchange, routing_key.to_s)

        job.opts['created_at'] = Time.now.to_i

        payload = job.payload
        exchange.publish(job.payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({routing_key: routing_key.to_s})) {
          connection.close {
          }
        }
      end
    end

    def purge_queue(*routing_keys)
      raise ArgumentError unless routing_keys && routing_keys.count > 0

      amqp_with_exchange do |connection, exchange|
        queues_purged = routing_keys.count

        messages_count = 0
        routing_keys.each do |routing_key|
          routing_key = routing_key.to_s
          queue = exchange.channel.queue(RabbitJobs.config.queue_name(routing_key), RabbitJobs.config[:queues][routing_key])
          queue.bind(exchange, :routing_key => routing_key)

          queue.status do |number_of_messages, number_of_consumers|
            messages_count += number_of_messages
            queue.purge {
              queues_purged -= 1
              if queues_purged == 0
                connection.close {
                  EM.stop
                  return messages_count
                }
              end
            }
          end
        end
      end
    end
  end
end