require 'rabbit_jobs/publisher/base'

module RabbitJobs
  class Publisher
    # AMQP publisher implementation.
    class Amqp < Base
      class << self
        def cleanup
          conn = Thread.current[:rj_publisher_connection]
          conn.close if conn && conn.status != :not_connected
          Thread.current[:rj_publisher_connection] = nil
        end

        def publish_to(routing_key, klass, *params)
          fail ArgumentError, "klass=#{klass.inspect}" unless klass.is_a?(Class) || klass.is_a?(String)
          routing_key = routing_key.to_sym unless routing_key.is_a?(Symbol)
          fail ArgumentError, "routing_key=#{routing_key}" unless RabbitJobs.config[:queues][routing_key]

          payload = Job.serialize(klass, *params)
          direct_publish_to(routing_key, payload)
        end

        def direct_publish_to(routing_key, payload, ex = {})
          ex = { name: ex.to_s } unless ex.is_a?(Hash)
          begin
            exchange_opts = Configuration::DEFAULT_MESSAGE_PARAMS.merge(ex || {})
            exchange_name = exchange_opts.delete(:name).to_s

            exchange = connection.default_channel.exchange(exchange_name, passive: true)
            exchange.on_return do |basic_deliver, properties, returned_payload|
              RJ.logger.error full_message: caller.join("\r\n"),
                              short_message: "AMQP ERROR: (#{basic_deliver[:reply_code]}) " \
                                             "#{basic_deliver[:reply_text]}. " \
                                             "exchange: #{basic_deliver[:exchange]}, " \
                                             "key: #{basic_deliver[:routing_key]}.",
                              _basic_deliver: basic_deliver.inspect,
                              _properties: properties.inspect,
                              _payload: returned_payload.inspect
              true
            end

            connection.default_channel.basic_publish(payload, exchange_name, routing_key, exchange_opts)
            unless connection.connected?
              fail "Disconnected from #{RJ.config.server}. Connection status: #{connection.try(:status).inspect}"
            end
          rescue
            RabbitJobs.logger.error $ERROR_INFO.message
            raise $ERROR_INFO
          end

          true
        end

        def purge_queue(*routing_keys)
          fail ArgumentError unless routing_keys.present?

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
            settings[:connection] = Bunny.new(
              RabbitJobs.config.server,
              properties: Bunny::Session::DEFAULT_CLIENT_PROPERTIES.merge(product: "rj_scheduler #{Process.pid}")
            ).start
          end
          settings[:connection]
        end
      end
    end
  end
end
