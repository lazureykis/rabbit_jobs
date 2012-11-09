# -*- encoding : utf-8 -*-

require 'json'
require 'amqp'
require 'eventmachine'
require 'uri'

module RabbitJobs
  module Publisher
    extend self

    def publish(klass, *params, &block)
      publish_to(RJ.config.default_queue, klass, *params, &block)
    end

    def publish_to(routing_key, klass, *params)
      raise ArgumentError.new("klass=#{klass.inspect}") unless klass && (klass.is_a?(Class) || klass.is_a?(String))
      raise ArgumentError.new("routing_key=#{routing_key}") unless routing_key && (routing_key.is_a?(Symbol) || routing_key.is_a?(String)) && !!RJ.config[:queues][routing_key.to_s]

      begin
        payload = {
          'class' => klass.to_s,
          'opts' => {'created_at' => Time.now.to_i},
          'params' => params
          }.to_json

        AmqpHelper.prepare_channel

        AMQP.channel.default_exchange.publish(payload, Configuration::DEFAULT_MESSAGE_PARAMS.merge({key: RJ.config.queue_name(routing_key.to_s)})) do
          yield if block_given?
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

      AmqpHelper.prepare_channel

      routing_keys.each do |routing_key|
        queue = AMQP.channel.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key.to_s])
        queue.status do |messages, consumers|
          # messages_count += messages
          queue.purge do |ret|
            raise "Cannot purge queue #{routing_key.to_s}." unless ret.is_a?(AMQ::Protocol::Queue::PurgeOk)
            messages_count += ret.message_count
            count -= 1
            if count == 0
              yield messages_count if block_given?
            end
          end
        end
      end
    end
  end
end