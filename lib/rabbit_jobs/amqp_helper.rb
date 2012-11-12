# -*- encoding : utf-8 -*-
require 'amqp'
require 'uri'

module RabbitJobs
  class AmqpHelper

    # Timeout to recover connection.
    RECOVERY_TIMEOUT = 3
    HOSTS_DEAD = []
    HOSTS_FAILED = {}

    class << self

      def prepare_connection
        if !AMQP.connection || AMQP.connection.closed?
          RJ.logger.info("Connecting to #{RJ.config.servers.first.to_s}...")
          AMQP.connection = AMQP.connect(RJ.config.servers.first, auto_recovery: true)
          init_auto_recovery
        end
      end

      def prepare_channel
        AMQP.channel ||= AMQP::Channel.new(AMQP.connection, auto_recovery: true)
      end

      def init_auto_recovery
        unless $auto_recovery_initiated
          $auto_recovery_initiated = true

          AMQP.connection.on_recovery do |conn, opts|
            HOSTS_DEAD.clear
            HOSTS_FAILED.clear
            url = url_from_opts opts
            RJ.logger.warn "[rj] Connection to #{url} recovered."
          end

          AMQP.connection.on_open do |conn, opts|
            RJ.logger.info "[rj] Connected."
          end

          # AMQP.connection.before_recovery do |conn, opts|
          #   RJ.logger.info "[rj] before_recovery"
          # end

          # AMQP.connection.on_possible_authentication_failure do |conn, opts|
          #   puts opts.inspect
          #   # restore_from_connection_failure(opts)
          # end

          AMQP.connection.on_tcp_connection_loss do |conn, opts|
            sleep 2
            restore_from_connection_failure(opts)
          end

          # AMQP.connection.on_connection_interruption do |conn|
          #   # restore_from_connection_failure(opts)
          # end

          AMQP.connection.on_tcp_connection_failure do |opts|
            sleep 2
            restore_from_connection_failure(opts)
          end
        end
      end

      private

      def restore_from_connection_failure(opts)
        url = opts.empty? ? RJ.config.servers.first : url_from_opts(opts)
        HOSTS_FAILED[url] ||= Time.now

        if HOSTS_FAILED[url] + RECOVERY_TIMEOUT < Time.now
          # reconnect to another host
          HOSTS_DEAD.push(url) unless HOSTS_DEAD.include?(url)
          new_url = (RJ.config.servers.dup - HOSTS_DEAD.dup).first
          if new_url
            reconnect_to(new_url)
          else
            # all hosts is dead
          end
        else
          # reconnect to the same host
          reconnect_to(url)
        end
      end

      def reconnect_to(url)
        if AMQP.connection
          RJ.logger.warn "[rj] Trying to reconnect to #{url}..."
          AMQP.connection.reconnect_to(url, 2)
        else
          RJ.logger.warn "[rj] Trying to connect to #{url}..."
          AMQP.connection = AMQP.connect(url, auto_recovery: true)
          init_auto_recovery
        end
      end

      def url_from_opts(opts = {})
        return "" unless opts
        return "" if opts.empty?
        s = ""
        s << (opts[:scheme] || "amqp")
        s << "://"
        s << "#{opts[:user]}@" if opts[:user] && !opts[:user].empty? && opts[:user] != 'guest'
        s << opts[:host]
        s << ":#{opts[:port]}" unless (opts[:scheme] == 'amqp' && opts[:port] == 5672) || (opts[:scheme] == 'amqps' && opts[:port] == 5673)
        s << opts[:vhost] if opts[:vhost] && !opts[:vhost].empty? && opts[:vhost] != "/"
        s
      end
    end
  end
end