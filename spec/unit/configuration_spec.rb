# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Configuration do
  it 'builds configuration from configure block' do
    RabbitJobs.configure do |c|
      c.disable_error_log

      c.url "amqp://somehost.lan"

      c.exchange 'my_exchange', durable: true, auto_delete: false

      c.queue 'durable_queue', durable: true,  auto_delete: false, ack: true, arguments: {'x-ha-policy' => 'all'}
      c.queue 'fast_queue',    durable: false, auto_delete: true,  ack: false
    end

    RabbitJobs.config.to_hash.should == {
      error_log: false,
      url: "amqp://somehost.lan",
      exchange: "my_exchange",
      exchange_params: {
        durable: true,
        auto_delete: false
      },
      queues: {
        "durable_queue" => {
          durable: true,
          auto_delete: false,
          ack: true,
          arguments: {"x-ha-policy"=>"all"}
        },
        "fast_queue" => {
          durable: false,
          auto_delete: true,
          ack: false
        },
      }
    }
  end

  it 'builds configuration from yaml' do
    RabbitJobs.config.load_file(File.expand_path('../../fixtures/config.yml', __FILE__))

    RabbitJobs.config.to_hash.should == {
      url: "amqp://example.com/vhost",
      exchange: "my_exchange",
      exchange_params: {
        durable: true,
        auto_delete: false
      },
      queues: {
        "durable_queue" => {
          durable: true,
          auto_delete: false,
          ack: true,
          arguments: {"x-ha-policy"=>"all"}
        },
        "fast_queue" => {
          durable: false,
          auto_delete: true,
          ack: false
        }
      }
    }
  end

  it 'use default config' do
    RabbitJobs.config.to_hash.should == {
      error_log: true,
      url: "amqp://localhost",
      exchange: "rabbit_jobs",
      exchange_params: {
        auto_delete: false,
        durable: true
      },
      queues: {
        "default" => {
          auto_delete: false,
          ack: true,
          durable: true
        }
      }
    }
  end

  it 'returns settings on some methods' do
    RabbitJobs.config.error_log == true
    RabbitJobs.config.url.should == 'amqp://localhost'
    RabbitJobs.config.routing_keys.should == ['default']
    RabbitJobs.config.exchange.should == 'rabbit_jobs'
    RabbitJobs.config.queue_name('default').should == 'rabbit_jobs#default'
  end
end