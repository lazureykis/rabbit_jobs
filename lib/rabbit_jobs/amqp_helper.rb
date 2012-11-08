# -*- encoding : utf-8 -*-
require 'amqp'
require 'uri'

module RabbitJobs
  class AmqpHelper

    class << self
      # Calls given block with initialized amqp connection.
      def with_amqp
        raise ArgumentError unless block_given?

        stop_reactor = !EM.reactor_running?

        AMQP.start(RJ.config.url) {
            puts "stop_reactor in amqp.run: #{stop_reactor}"
            yield stop_reactor
        }
      end

      def prepare_channel
        AMQP.channel ||= AMQP::Channel.new
      end
    end
  end
end