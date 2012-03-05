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

      b = Bunny.new(host: RJ.config.host, logging: false)
      b.start

      exchange = b.exchange(RJ.config[:exchange], RJ.config[:exchange_params])
      queue = b.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key.to_s])
      queue.bind(exchange)

      exchange.publish(job.payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({key: routing_key.to_s}))
      b.stop
    end

    def purge_queue(*routing_keys)
      raise ArgumentError unless routing_keys && routing_keys.count > 0

      b = Bunny.new(host: RJ.config.host, logging: false)
      b.start

      messages_count = 0
      routing_keys.each do |routing_key|
        queue = b.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key.to_s])
        messages_count += queue.status[:message_count]
        queue.purge
      end
      b.stop
      return messages_count
    end

    def publish_to2(routing_key, klass, *params)
      raise ArgumentError unless klass && routing_key && klass.is_a?(Class) && (routing_key.is_a?(Hash) || routing_key.is_a?(String))

      job = klass.new(*params)
      job.opts = {}

      dont_stop_em = defined?(EM) && EM.reactor_running?
      dont_close_connection = AMQP.connection && AMQP.connection.open?

      amqp_with_exchange do |connection, exchange|

        queue = make_queue(exchange, routing_key.to_s)

        job.opts['created_at'] = Time.now.to_i

        payload = job.payload
        exchange.publish(job.payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({routing_key: routing_key.to_s})) {
          unless dont_close_connection
            connection.close {
              EM.stop unless dont_stop_em
            }
          end
        }
      end
    end

    def purge_queue2(*routing_keys)
      raise ArgumentError unless routing_keys && routing_keys.count > 0

      dont_stop_em = defined?(EM) && EM.reactor_running?
      dont_close_connection = AMQP.connection && AMQP.connection.open?

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

                if dont_close_connection
                  puts 'return with not closed connection'
                  return messages_count
                else
                  connection.close {
                    EM.stop unless dont_stop_em
                    return messages_count
                  }
                end
              end
            }
          end
        end
      end
    end
  end
end