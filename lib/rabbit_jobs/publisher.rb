# -*- encoding : utf-8 -*-

module RabbitJobs
  module Publisher
    extend self

    def cleanup
      conn = Thread.current[:rj_publisher_connection]
      conn.close if conn && conn.status != :not_connected
      Thread.current[:rj_publisher_connection] = nil
    end

    def publish_to(routing_key, klass, *params)
      raise ArgumentError.new("klass=#{klass.inspect}") unless klass.is_a?(Class) || klass.is_a?(String)
      routing_key = routing_key.to_sym unless routing_key.is_a?(Symbol)
      raise ArgumentError.new("routing_key=#{routing_key}") unless RabbitJobs.config[:queues][routing_key]

      payload = Job.serialize(klass, *params)
      direct_publish_to(routing_key, payload)
    end

    def direct_publish_to(routing_key, payload, ex = {})
      ex = {name: ex.to_s} unless ex.is_a?(Hash)
      check_connection
      begin
        exchange_opts = Configuration::DEFAULT_MESSAGE_PARAMS.merge(ex || {})
        exchange_name = exchange_opts.delete(:name).to_s
        connection.default_channel.basic_publish(payload, exchange_name, routing_key, exchange_opts)
      rescue
        RabbitJobs.logger.warn $!.message
        RabbitJobs.logger.warn $!.backtrace.join("\n")
        raise $!
      end

      true
    end

    def purge_queue(*routing_keys)
      raise ArgumentError unless routing_keys.present?
      check_connection

      messages_count = 0
      routing_keys.map(&:to_sym).each do |routing_key|
        queue = connection.default_channel.queue(routing_key, RabbitJobs.config[:queues][routing_key])
        messages_count += queue.status[:message_count].to_i
        connection.default_channel.queue_purge(routing_key)
      end

      messages_count
    end

    private

    def settings
      Thread.current[:rj_publisher] ||= {}
    end

    def connection
      unless settings[:connection]
        settings[:connection] = Bunny.new(RabbitJobs.config.server, :heartbeat_interval => 5)
        settings[:connection].start
        # settings[:channel] = settings[:connection].create_channel
        # settings[:channel].confirm_select
      end
      settings[:connection]
    end

    def check_connection
      unless connection.connected?
        connection.start if connection.status == :disconnected
        raise "Disconnected from #{RJ.config.server}. Connection status: #{connection.try(:status).inspect}"
      end
    end
  end
end
