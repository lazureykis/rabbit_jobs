module RabbitJobs
  class Publisher
    class Base
      class << self
        def cleanup
          raise NotImplementedError
        end

        def publish_to(routing_key, klass, *params)
          raise NotImplementedError
        end

        def direct_publish_to(routing_key, payload, ex = {})
          raise NotImplementedError
        end

        def purge_queue(*routing_keys)
          raise NotImplementedError
        end
      end
    end
  end
end