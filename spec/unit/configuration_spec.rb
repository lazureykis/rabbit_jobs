# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Configuration do
  it 'builds configuration from configure block' do
    RabbitJobs.configure do |c|
      c.disable_error_log

      c.server "amqp://somehost.lan"

      c.queue 'durable_queue', durable: true,  auto_delete: false, ack: true, arguments: {'x-ha-policy' => 'all'}
      c.queue 'fast_queue',    durable: false, auto_delete: true,  ack: false
    end

    RabbitJobs.config.to_hash.should == {
      error_log: false,
      server: "amqp://somehost.lan",
      queues: {
        durable_queue: {
          auto_delete: false,
          exclusive: false,
          durable: true,
          ack: true,
          arguments: {"x-ha-policy"=>"all"}
        },
        fast_queue: {
          auto_delete: true,
          exclusive: false,
          durable: false,
          ack: false
        }
      }
    }
  end

  it 'builds configuration from yaml' do
    RabbitJobs.config.load_file(File.expand_path('../../fixtures/config.yml', __FILE__))

    RabbitJobs.config.to_hash.should == {
      server: "amqp://example.com/vhost",
      queues: {
        durable_queue: {
          durable: true,
          exclusive: false,
          auto_delete: false,
          ack: true,
          arguments: {"x-ha-policy"=>"all"}
        },
        fast_queue: {
          durable: false,
          exclusive: false,
          auto_delete: true,
          ack: false
        }
      }
    }
  end

  it 'use default value for #server' do
    RabbitJobs.config.to_hash.should == {
      error_log: true,
      server: "amqp://localhost",
      queues: {}
    }
  end

  it 'returns settings on some methods' do
    RabbitJobs.config.error_log == true
    RabbitJobs.config.server.should == 'amqp://localhost'
    RabbitJobs.config.routing_keys.should == []
  end
end