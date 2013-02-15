# -*- encoding : utf-8 -*-
require 'amqp'
require 'uri'

module RabbitJobs
  class AmqpHelper

    # Timeout to recover connection.
    RECOVERY_TIMEOUT = 3
    HOSTS_DEAD = []
    HOSTS_FAILED = {}
    AUTO_RECOVERY_ENABLED = true

    class << self

      def prepare_connection(conn)
        if !conn
          RJ.logger.info("Connecting to #{RJ.config.servers.first.to_s}...")
          conn = AMQP.connect(RJ.config.servers.first, auto_recovery: AUTO_RECOVERY_ENABLED)
          init_auto_recovery(conn) if AUTO_RECOVERY_ENABLED
        elsif conn.closed?
          conn.reconnect
        end
        conn
      end

      def create_channel(connection)
        AMQP::Channel.new(connection, auto_recovery: AUTO_RECOVERY_ENABLED)
      end

      def init_auto_recovery(connection)
        connection.on_recovery do |conn, opts|
          HOSTS_DEAD.clear
          HOSTS_FAILED.clear
          url = url_from_opts opts
          RJ.logger.warn "Connection to #{url} recovered."
        end

        connection.on_open do |conn, opts|
          RJ.logger.info "Connected."
        end

        connection.on_tcp_connection_loss do |conn, opts|
          sleep 2
          restore_from_connection_failure(conn, opts)
        end

        connection.on_tcp_connection_failure do |opts|
          sleep 2
          restore_from_connection_failure(connection, opts)
        end


        # connection.before_recovery do |conn, opts|
        #   RJ.logger.info "before_recovery"
        # end

        # connection.on_possible_authentication_failure do |conn, opts|
        #   puts opts.inspect
        #   # restore_from_connection_failure(conn, opts)
        # end

        # connection.on_connection_interruption do |conn|
        #   # restore_from_connection_failure(conn, opts)
        # end
      end

      private

      def restore_from_connection_failure(connection, opts)
        url = opts.empty? ? RJ.config.servers.first : url_from_opts(opts)
        HOSTS_FAILED[url] ||= Time.now

        if HOSTS_FAILED[url] + RECOVERY_TIMEOUT < Time.now
          # reconnect to another host
          HOSTS_DEAD.push(url) unless HOSTS_DEAD.include?(url)
          new_url = (RJ.config.servers.dup - HOSTS_DEAD.dup).first
          if new_url
            reconnect_to(connection, new_url)
          else
            # all hosts is dead
          end
        else
          # reconnect to the same host
          reconnect_to(connection, url)
        end
      end

      def reconnect_to(connection, url)
        if connection
          RJ.logger.warn "Trying to reconnect to #{url}..."
          connection.reconnect_to(url, 2)
        else
          RJ.logger.warn "Trying to connect to #{url}..."
          connection = AMQP.connect(url, auto_recovery: true)
          init_auto_recovery(connection)
        end
      end

      def url_from_opts(opts = {})
        return "" unless opts
        return "" if opts.empty?

        scheme = opts[:scheme] || "amqp"
        vhost = opts[:vhost] || "/"
        vhost = "/#{vhost}" unless vhost[0] == '/'
        use_default_port = (scheme == 'amqp' && opts[:port] == 5672) || (scheme == 'amqps' && opts[:port] == 5673)
        use_default_credentials = opts[:user] == 'guest' && opts[:pass] == 'guest'

        s = ""
        s << scheme
        s << "://"
        s << "#{opts[:user]}:#{opts[:pass]}@" unless use_default_credentials
        s << opts[:host]
        s << ":#{opts[:port]}" unless use_default_port
        s << vhost
        s
      end
    end
  end
end