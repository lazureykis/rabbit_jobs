module RabbitJobs
  # Connection manager.
  module AmqpTransport
    class << self
      def amqp_connection
        @amqp_connection ||= Bunny.new(
          RabbitJobs.config.server,
          automatically_recover: false,
          properties: Bunny::Session::DEFAULT_CLIENT_PROPERTIES.merge(product: "rabbit_jobs #{Process.pid}")
        ).start
      end

      def publisher_channel
        @publisher_channel ||= amqp_connection.create_channel(2)
      end

      def consumer_channel
        @consumer_channel ||= amqp_connection.create_channel(1)
      end

      def amqp_cleanup
        conn = @amqp_connection
        @amqp_connection = nil

        conn.stop if conn && conn.status != :not_connected
        @consumer_channel.work_pool.join if @consumer_channel
        @publisher_channel = nil
        @consumer_channel = nil
        true
      end
    end
  end
end
