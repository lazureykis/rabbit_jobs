# -*- encoding : utf-8 -*-

require 'json'
require 'amqp'
require 'eventmachine'
require 'uri'

module RabbitJobs
  module Publisher
    extend self

    def publish(klass, *params)
      publish_to(RJ.config.default_queue, klass, *params)
    end

    def publish_to(routing_key, klass, *params)
      raise ArgumentError unless klass && (klass.is_a?(Class) || klass.is_a?(String))
      raise ArgumentError unless routing_key && (routing_key.is_a?(Symbol) || routing_key.is_a?(String)) && !!RJ.config[:queues][routing_key.to_s]

      begin
        close_connection = !EM.reactor_running?
        AmqpHelpers.with_amqp do |connection, stop_em|
          channel = AMQP::Channel.new(connection)

          channel.on_error do |ch, channel_close|
            puts "Channel-level error: #{channel_close.reply_text}, shutting down..."
            connection.disconnect { EM.stop }
          end

          exchange = channel.direct(RJ.config[:exchange], RJ.config[:exchange_params])
          queue = channel.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key.to_s])
          queue.bind(exchange, :routing_key => routing_key)

          payload = {
            'class' => klass.to_s,
            'opts' => {'created_at' => Time.now.to_i},
            'params' => params
            }.to_json

          exchange.publish(payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({key: routing_key.to_s})) do
            if stop_em
              connection.disconnect { EM.stop }
            end
          end
        end
      rescue
        raise $!
        RJ.logger.warn $!.inspect
        RJ.logger.warn $!.backtrace.join("\n")
      end

      true
    end

    def purge_queue(*routing_keys)
      raise ArgumentError unless routing_keys && routing_keys.count > 0

      messages_count = 0

      count = routing_keys.count

      AmqpHelpers.with_amqp do |connection, stop_em|
        channel = AMQP::Channel.new(connection)

        channel.on_error do |ch, channel_close|
          puts "Channel-level error: #{channel_close.reply_text}, shutting down..."
          connection.disconnect { EM.stop }
        end

        exchange = channel.direct(RJ.config[:exchange], RJ.config[:exchange_params])

        routing_keys.each do |routing_key|
          queue = channel.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key.to_s])
          queue.bind(exchange, :routing_key => routing_key)
          queue.status do |messages, consumers|
            # messages_count += messages
            queue.purge do |ret|
              raise "Cannot purge queue #{routing_key.to_s}." unless ret.is_a?(AMQ::Protocol::Queue::PurgeOk)
              messages_count += ret.message_count
              count -= 1
              if count == 0 && stop_em
                connection.disconnect { EM.stop }
              end
            end
          end
        end

      end

      return messages_count
    end
  end
end