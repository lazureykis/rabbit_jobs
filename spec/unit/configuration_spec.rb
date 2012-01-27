# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Configuration do
  before(:each) do
    RabbitJobs.class_variable_set '@@configuration', nil
  end

  it 'builds configuration from configure block' do
    RabbitJobs.configure do |c|
      c.host "somehost.lan"

      c.exchange 'my_exchange', durable: true, auto_delete: false

      c.queue 'durable_queue', durable: true,  auto_delete: false, ack: true, arguments: {'x-ha-policy' => 'all'}
      c.queue 'fast_queue',    durable: false, auto_delete: true,  ack: false
    end

    RabbitJobs.config.to_hash.should == {
      host: "somehost.lan",
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
      host: "example.com",
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
      host: "localhost",
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
    RabbitJobs.config.host.should == 'localhost'
    RabbitJobs.config[:host].should == 'localhost'
    RabbitJobs.config.routing_keys.should == ['default']
    RabbitJobs.config.exchange.should == 'rabbit_jobs'
    RabbitJobs.config.queue_name('default').should == 'rabbit_jobs#default'
  end
end