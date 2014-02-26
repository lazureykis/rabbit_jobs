require 'rabbit_jobs/publisher/base'

module RabbitJobs
  class Publisher
    class Amqp < Base
      class << self

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
          begin
            exchange_opts = Configuration::DEFAULT_MESSAGE_PARAMS.merge(ex || {})
            exchange_name = exchange_opts.delete(:name).to_s

            exchange = connection.default_channel.exchange(exchange_name, passive: true)
            exchange.on_return do |basic_deliver, properties, payload|
              RJ.logger.error full_message: caller.join("\r\n"),
                short_message: "AMQP ERROR: (#{basic_deliver[:reply_code]}) #{basic_deliver[:reply_text].to_s}. exchange: #{basic_deliver[:exchange]}, key: #{basic_deliver[:routing_key]}.",
                _basic_deliver: basic_deliver.inspect, _properties: properties.inspect, _payload: payload.inspect
              true
            end

            unless connection.default_channel.basic_publish(payload, exchange_name, routing_key, exchange_opts).connection.connected?
              raise "Disconnected from #{RJ.config.server}. Connection status: #{connection.try(:status).inspect}"
            end
          rescue
            RabbitJobs.logger.error $!.message
            raise $!
          end

          true
        end

        def purge_queue(*routing_keys)
          raise ArgumentError unless routing_keys.present?

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
            settings[:connection] = Bunny.new(RabbitJobs.config.server)
            settings[:connection].start
          end
          settings[:connection]
        end
      end
    end
  end
end
