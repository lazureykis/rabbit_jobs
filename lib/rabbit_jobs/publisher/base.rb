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
      end
    end
  end
end
