require 'rabbit_jobs/publisher/amqp'
require 'rabbit_jobs/publisher/test'

module RabbitJobs
  class Publisher
    class << self

      @publisher_type = Amqp

      def mode
        case @publisher_type
        when Amqp
          :amqp
        when Test
          :test
        end
      end

      def mode=(value)
        @publisher_type = case value.to_s
        when 'amqp'
          Amqp
        when 'test'
          Test
        else
          raise ArgumentError.new("value must be :amqp or :test. Passed: #{value.inspect}")
        end
      end

      %i(cleanup publish_to direct_publish_to purge_queue).each do |api_method|
        delegate api_method, to: :publisher_type
      end

      private

      def publisher_type
        @publisher_type
      end
    end
  end
end

RabbitJobs::Publisher.mode ||= :amqp