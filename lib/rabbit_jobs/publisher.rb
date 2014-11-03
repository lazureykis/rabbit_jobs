require 'rabbit_jobs/publisher/amqp'
require 'rabbit_jobs/publisher/test'
require 'rabbit_jobs/publisher/sync'

module RabbitJobs
  # Interface for publishing messages to amqp queues or testing queues.
  class Publisher
    class << self
      def mode
        publisher_type.class_name.underscore
      end

      # Allows to switch publisher implementations.
      # You can use RJ.publisher.mode = :test in testing environment.
      def mode=(value)
        @publisher_type = case value.to_s
                          when 'amqp'
                            Amqp
                          when 'test'
                            Test
                          when 'sync'
                            Sync
                          else
                            fail ArgumentError, "value must be :amqp, :sync or :test. Passed: #{value.inspect}"
                          end
      end

      %i(cleanup publish_to direct_publish_to purge_queue).each do |api_method|
        delegate api_method, to: :publisher_type
      end

      private

      # Default publisher type is Amqp.
      def publisher_type
        @publisher_type || Amqp
      end
    end
  end
end
