require 'rabbit_jobs/publisher/amqp'
require 'rabbit_jobs/publisher/test'
require 'rabbit_jobs/publisher/sync'

module RabbitJobs
  class Publisher
    class << self
      def mode
        publisher_type.class_name.underscore
      end

      def mode=(value)
        @publisher_type = case value.to_s
        when 'amqp'
          Amqp
        when 'test'
          Test
        when 'sync'
          Sync
        else
          raise ArgumentError.new("value must be :amqp or :test. Passed: #{value.inspect}")
        end
      end

      %i(cleanup publish_to direct_publish_to purge_queue).each do |api_method|
        delegate api_method, to: :publisher_type
      end

      private

      def publisher_type
        @publisher_type || Amqp
      end
    end
  end
end