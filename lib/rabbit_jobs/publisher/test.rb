require 'rabbit_jobs/publisher/base'

module RabbitJobs
  class Publisher
    # Publisher for testing.
    # Stores passed messages to array.
    class Test < Base
      class << self
        def cleanup
          messages.clear
        end

        def publish_to(routing_key, klass, *params)
          fail ArgumentError, "klass=#{klass.inspect}" unless klass.is_a?(Class) || klass.is_a?(String)
          routing_key = routing_key.to_sym unless routing_key.is_a?(Symbol)
          fail ArgumentError, "routing_key=#{routing_key}" unless RabbitJobs.config[:queues][routing_key]

          payload = Job.serialize(klass, *params)
          direct_publish_to(routing_key, payload)
        end

        def direct_publish_to(routing_key, payload, ex = {})
          exchange_name = ex.is_a?(Hash) ? ex[:name] : ex
          messages.push payload: payload, exchange_name: exchange_name.to_s, routing_key: routing_key.to_s
          true
        end

        def purge_queue(*routing_keys)
          fail ArgumentError unless routing_keys.present?

          ret = messages.count
          messages.clear
          ret
        end

        private

        def messages
          @messages ||= []
        end
      end
    end
  end
end
