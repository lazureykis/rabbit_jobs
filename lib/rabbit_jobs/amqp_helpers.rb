# -*- encoding : utf-8 -*-

module RabbitJobs
  module AmqpHelpers

    # Calls given block with initialized amqp
    def amqp_with_exchange(&block)
      raise ArgumentError unless block

      AMQP.start(host: RabbitJobs.config.host) do |connection|
        channel  = AMQP::Channel.new(connection)

        channel.on_error do |ch, channel_close|
          puts "Channel-level error: #{channel_close.reply_text}, shutting down..."
          connection.close { EM.stop }
        end

        exchange = channel.direct(RabbitJobs.config[:exchange], RabbitJobs.config[:exchange_params])

        # go work
        block.call(connection, exchange)
      end
    end

    def em_amqp_with_exchange(&block)
      raise ArgumentError unless block

      connection = AMQP.connect(host: RabbitJobs.config.host)
      channel = AMQP::Channel.new(connection)

      channel.on_error do |ch, channel_close|
        puts "Channel-level error: #{channel_close.reply_text}, shutting down..."
        connection.close { EM.stop }
      end

      exchange = channel.direct(RabbitJobs.config[:exchange], RabbitJobs.config[:exchange_params])

      # go work
      block.call(connection, exchange)
    end

    def amqp_with_queue(routing_key, &block)

      raise ArgumentError unless routing_key && block

      amqp_with_exchange do |connection, exchange|
        queue = exchange.channel.queue(RabbitJobs.config.queue_name(routing_key), RabbitJobs.config[:queues][routing_key])
        queue.bind(exchange, :routing_key => routing_key)

        # go work
        block.call(connection, queue)
      end
    end

    def make_queue(exchange, routing_key)
      queue = exchange.channel.queue(RabbitJobs.config.queue_name(routing_key), RabbitJobs.config[:queues][routing_key])
      queue.bind(exchange, :routing_key => routing_key)
      queue
    end
  end
end