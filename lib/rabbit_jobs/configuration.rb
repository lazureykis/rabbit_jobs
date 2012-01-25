# -*- encoding : utf-8 -*-

module RabbitJobs
  class Configuration
    def self.host
      "localhost"
    end

    def self.queue_params
      {
        auto_delete: false,
        ack: true,
        durable: true,
        arguments: {'x-ha-policy' => 'all'}
      }
    end

    def self.queue_name
      [exchange_name, routing_key].join('#')
    end

    def self.exchange_params
      {
        durable: true,
        auto_delete: false
      }
    end

    def self.exchange_name
      "test_exchange"
    end

    def self.routing_key
      "rabbit_jobs_test"
    end

    def self.publish_params
      {
        persistent: true,
        nowait: false,
        # immediate: true
      }
    end
  end
end