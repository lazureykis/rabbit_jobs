require 'rabbit_jobs/publisher/amqp'
require 'rabbit_jobs/publisher/test'
require 'rabbit_jobs/publisher/sync'

module RabbitJobs
  # Interface for publishing messages to amqp queues or testing queues.
  class Publisher
    class << self
      def mode
        publisher_instance.class_name.underscore
      end

      # Allows to switch publisher implementations.
      # You can use RJ.publisher.mode = :test in testing environment.
      def mode=(value)
        @publisher_instance = case value.to_s
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

      delegate :cleanup, :publish_to, :direct_publish_to, :purge_queue, :queue_status, to: :publisher_instance

      private

      # Default publisher type is Amqp.
      def publisher_instance
        @publisher_instance || Amqp
      end
    end
  end
end
