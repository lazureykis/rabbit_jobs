require 'rabbit_jobs/publisher/base'

module RabbitJobs
  class Publisher
    # AMQP publisher implementation.
    class Amqp < Base
      class << self
        delegate :amqp_cleanup, :amqp_connection, :publisher_channel, to: RabbitJobs

        def cleanup
          amqp_cleanup
        end

        def publish_to(routing_key, klass, *params)
          check_amqp_publishing_params(routing_key, klass)

          payload = Job.serialize(klass, *params)
          direct_publish_to(routing_key.to_sym, payload)
        end

        def direct_publish_to(routing_key, payload, ex = {})
          exchange_name, exchange_opts = build_exchange(ex)
          publisher_channel.basic_publish(payload, exchange_name, routing_key, exchange_opts)

          fail "Disconnected from #{RJ.config.server}." unless amqp_connection.connected?
          true
        rescue
          RabbitJobs.logger.error $!.message
          raise $!
        end

        def purge_queue(*routing_keys)
          fail ArgumentError unless routing_keys.present?

          routing_keys.map(&:to_sym).each do |routing_key|
            publisher_channel.queue_purge(routing_key)
          end
        end

        def queue_status(routing_key)
          check_queue_status_params(routing_key)
          publisher_channel.queue(routing_key, RabbitJobs.config[:queues][routing_key.to_sym]).status
        end

        private

        def build_exchange(ex)
          ex = { name: ex.to_s } unless ex.is_a?(Hash)
          exchange_opts = Configuration::DEFAULT_MESSAGE_PARAMS.merge(ex || {})
          exchange_name = exchange_opts.delete(:name).to_s

          exchange = publisher_channel.exchange(exchange_name, passive: true)
          exchange_on_return_policy(exchange)
          [exchange_name, exchange_opts]
        end

        def exchange_on_return_policy(exchange)
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
        end
      end
    end
  end
end
