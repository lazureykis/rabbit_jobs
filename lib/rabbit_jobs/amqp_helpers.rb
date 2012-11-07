# -*- encoding : utf-8 -*-
require 'amqp'
require 'uri'

module RabbitJobs
  module AmqpHelpers

    class << self
      # Calls given block with amqp connection.
      # Assumes that amqp connection already initialized when reactor is running.
      def with_amqp
        raise ArgumentError unless block_given?

        if EM.reactor_running?
          raise NotImplementedError("TODO")
          connected = AMQP.connection && AMQP.connection.open?
          connection = connected ? AMQP.connection : AMQP.connect(RJ.config.url)
          yield connection, false
        else
          EM.run {
            # connection = AMQP.connect(host: 'localhost', port: 5672, user: 'guest', pass: 'guest')
            connection = AMQP.connect(RJ.config.url)

            yield connection, true
          }
        end
      end

      # Calls given block with initialized amqp
      def amqp_with_exchange
        raise ArgumentError unless block_given?

        with_amqp do |connection, stop_em|
          channel = AMQP::Channel.new(connection)
          exchange = channel.direct(RJ.config[:exchange], RJ.config[:exchange_params])
          yield connection, exchange, stop_em
        end
      end

      def amqp_with_queue(routing_key)
        raise ArgumentError unless routing_key && block_given?

        amqp_with_exchange do |connection, exchange, stop_em|
          channel = AMQP::Channel.new(connection)
          exchange = channel.direct(RJ.config[:exchange], RJ.config[:exchange_params])
          queue = channel.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key])
          queue.bind(exchange, :routing_key => routing_key)
          yield connection, queue, stop_em
        end
      end
    end
  end
end