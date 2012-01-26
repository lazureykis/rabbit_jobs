

module RabbitJobs
  module Helpers
    def symbolize_keys!(hash)
      hash.inject({}) do |options, (key, value)|
        options[(key.to_sym rescue key) || key] = value
        options
      end
    end

    # Calls given block with initialized amqp
    def with_queue(routing_key, &block)

      raise ArgumentError unless routing_key && block


      AMQP.start(host: RabbitJobs.config.host) do |connection|
        channel  = AMQP::Channel.new(connection)

        channel.on_error do |ch, channel_close|
          puts "Channel-level error: #{channel_close.reply_text}, shutting down..."
          connection.close { EM.stop }
        end

        exchange = channel.direct(RabbitJobs.config[:exchange], RabbitJobs.config[:exchange_params])
        queue    = channel.queue(RabbitJobs.config.queue_name(routing_key), RabbitJobs.config[:queues][routing_key])
        queue.bind(exchange, :routing_key => routing_key)

        # go work
        block.call(connection, exchange, queue)
      end
    end
  end
end