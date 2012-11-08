# -*- encoding : utf-8 -*-
require 'amqp'
require 'uri'

module RabbitJobs
  class AmqpHelper

    class << self
      # Calls given block with initialized amqp connection.
      def with_amqp
        raise ArgumentError unless block_given?

        if EM.reactor_running?
          yield false
        else
          AMQP.start(RJ.config.connection_options) {
            init_auto_recovery
            yield true
          }
        end
      end

      def prepare_channel
        unless AMQP.channel
          create_channel
        else
          create_channel unless AMQP.channel.open?
        end
      end

      private

      def init_auto_recovery
        AMQP.connection.on_recovery do |conn, opts|
          url = url_from_opts opts
          RJ.logger.warn "[network failure] Connection to #{url} established."
        end

        AMQP.connection.on_tcp_connection_loss do |conn, opts|
          url = url_from_opts opts
          RJ.logger.warn "[network failure] Trying to reconnect to #{url}..."
          conn.reconnect(false, 2)
        end
      end

      def url_from_opts(opts = {})
        s = ""
        s << opts[:scheme]
        s << "://"
        s << "#{opts[:user]}@" if opts[:user] && opts[:user] != 'guest'
        s << opts[:host]
        s << ":#{opts[:port]}" unless (opts[:scheme] == 'amqp' && opts[:port] == 5672) || (opts[:scheme] == 'amqps' && opts[:port] == 5673)
        s << opts[:vhost]
      end

      def create_channel
        AMQP.channel = AMQP::Channel.new(AMQP.connection, auto_recovery: true)
      end
    end
  end
end