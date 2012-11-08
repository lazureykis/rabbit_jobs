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
      raise ArgumentError.new("klass=#{klass.inspect}") unless klass && (klass.is_a?(Class) || klass.is_a?(String))
      raise ArgumentError.new("routing_key=#{routing_key}") unless routing_key && (routing_key.is_a?(Symbol) || routing_key.is_a?(String)) && !!RJ.config[:queues][routing_key.to_s]

      begin
        AmqpHelper.with_amqp do |stop_em|
          AmqpHelper.prepare_channel

          payload = {
            'class' => klass.to_s,
            'opts' => {'created_at' => Time.now.to_i},
            'params' => params
            }.to_json

          AMQP::Exchange.default.publish(payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({key: RJ.config.queue_name(routing_key.to_s)})) do
            if stop_em
              AMQP.connection.disconnect { EM.stop }
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

      AmqpHelper.with_amqp do |stop_em|
        routing_keys.each do |routing_key|
          queue = AMQP.channel.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key.to_s])
          queue.status do |messages, consumers|
            # messages_count += messages
            queue.purge do |ret|
              raise "Cannot purge queue #{routing_key.to_s}." unless ret.is_a?(AMQ::Protocol::Queue::PurgeOk)
              messages_count += ret.message_count
              count -= 1
              if count == 0 && stop_em
                AMQP.connection.disconnect { EM.stop }
              end
            end
          end
        end
      end

      return messages_count
    end
  end
end