require 'rabbit_jobs/publisher/base'

module RabbitJobs
  class Publisher
    # Synchronous publisher.
    # Calls Job#perform with no RabbitMQ interaction.
    class Sync < Base
      class << self
        def cleanup
        end

        def publish_to(routing_key, klass, *params)
          fail ArgumentError, "klass=#{klass.inspect}" unless klass.is_a?(Class) || klass.is_a?(String)
          routing_key = routing_key.to_sym unless routing_key.is_a?(Symbol)
          fail ArgumentError, "routing_key=#{routing_key}" unless RabbitJobs.config[:queues][routing_key]

          klass.perform(*params)
        end

        def purge_queue(*routing_keys)
          fail ArgumentError unless routing_keys.present?
        end

        def queue_status(routing_key)
          check_queue_status_params(routing_key)
          { message_count: 0, consumer_count: 0 }
        end
      end
    end
  end
end
