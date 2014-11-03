module RabbitJobs
  class Publisher
    # Abstract publisher.
    class Base
      class << self
        def cleanup
          fail NotImplementedError
        end

        def publish_to(_routing_key, _klass, *_params)
          fail NotImplementedError
        end

        def direct_publish_to(_routing_key, _payload, _ex = {})
          fail NotImplementedError
        end

        def purge_queue(*_routing_keys)
          fail NotImplementedError
        end

        protected

        def check_amqp_publishing_params(routing_key, klass)
          fail ArgumentError, "klass=#{klass.inspect}" unless klass.is_a?(Class) || klass.is_a?(String)
          routing_key = routing_key.to_sym unless routing_key.is_a?(Symbol)
          fail ArgumentError, "routing_key=#{routing_key}" unless RabbitJobs.config[:queues][routing_key]
        end
      end
    end
  end
end
