require 'rabbit_jobs/publisher/base'

module RabbitJobs
  class Publisher
    # Publisher for testing.
    # Stores AMQP messages to array.
    class Test < Base
      class << self
        def cleanup
          messages.clear
        end

        def publish_to(routing_key, klass, *params)
          check_amqp_publishing_params(routing_key, klass)

          payload = Job.serialize(klass, *params)
          direct_publish_to(routing_key.to_sym, payload)
        end

        def direct_publish_to(routing_key, payload, ex = {})
          exchange_name = ex.is_a?(Hash) ? ex[:name] : ex
          messages.push payload: payload, exchange_name: exchange_name.to_s, routing_key: routing_key.to_s
          true
        end

        def purge_queue(*routing_keys)
          fail ArgumentError unless routing_keys.present?
          messages.clear
        end

        def queue_status(routing_key)
          check_queue_status_params(routing_key)
          { message_count: messages.count, consumer_count: 0 }
        end

        private

        def messages
          @messages ||= []
        end
      end
    end
  end
end
