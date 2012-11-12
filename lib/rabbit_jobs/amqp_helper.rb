# -*- encoding : utf-8 -*-
require 'amqp'
require 'uri'

module RabbitJobs
  class AmqpHelper

    class << self

      def prepare_connection
        if !AMQP.connection || AMQP.connection.closed?
          AMQP.connection = AMQP.connect(RJ.config.url)
          init_auto_recovery
        end
      end

      def prepare_channel
        AMQP.channel ||= AMQP::Channel.new(AMQP.connection, auto_recovery: true)
      end

      def init_auto_recovery
        AMQP.connection.on_recovery do |conn, opts|
          url = url_from_opts opts
          RJ.logger.warn "[network failure] Connection to #{url} established."
        end

        AMQP.connection.on_tcp_connection_loss do |conn, opts|
          url = url_from_opts(opts)
          RJ.logger.warn "[network failure] Trying to reconnect to #{url}..."
          puts "[network failure] Trying to reconnect to #{url}..."
          conn.reconnect(false, 2)
        end
      end

      private

      def url_from_opts(opts = {})
        return "" unless opts
        return "" if opts.empty?
        s = ""
        s << (opts[:scheme] || "amqp")
        s << "://"
        s << "#{opts[:user]}@" if opts[:user] && opts[:user] != 'guest'
        s << opts[:host]
        s << ":#{opts[:port]}" unless (opts[:scheme] == 'amqp' && opts[:port] == 5672) || (opts[:scheme] == 'amqps' && opts[:port] == 5673)
        s << opts[:vhost]
      end
    end
  end
end