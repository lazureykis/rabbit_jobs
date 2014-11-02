require 'spec_helper'

describe RabbitJobs::Configuration do
  around(:each) do |example|
    old_config = RJ.instance_variable_get '@configuration'
    RJ.instance_variable_set '@configuration', nil
    example.run
    RJ.instance_variable_set '@configuration', old_config
  end

  it 'builds configuration from configure block' do
    RabbitJobs.configure do |c|
      c.disable_error_log

      c.server 'amqp://somehost.lan'

      c.queue 'durable_queue', durable: true,  auto_delete: false, manual_ack: true, arguments: { 'x-ha-policy' => 'all' }
      c.queue 'fast_queue',    durable: false, auto_delete: true,  manual_ack: false
    end

    RabbitJobs.config.to_hash.should == {
      error_log: false,
      server: 'amqp://somehost.lan',
      queues: {
        jobs: {
          auto_delete: false,
          exclusive: false,
          durable: true,
          manual_ack: true
        },
        durable_queue: {
          auto_delete: false,
          exclusive: false,
          durable: true,
          manual_ack: true,
          arguments: { 'x-ha-policy' => 'all' }
        },
        fast_queue: {
          auto_delete: true,
          exclusive: false,
          durable: false,
          manual_ack: false
        }
      }
    }
  end

  it 'builds configuration from yaml' do
    RabbitJobs.config.load_file(File.expand_path('../../fixtures/config.yml', __FILE__))

    RabbitJobs.config.to_hash.should == {
      server: 'amqp://example.com/vhost',
      queues: {
        durable_queue: {
          durable: true,
          exclusive: false,
          auto_delete: false,
          manual_ack: true,
          arguments: { 'x-ha-policy' => 'all' }
        },
        fast_queue: {
          durable: false,
          exclusive: false,
          auto_delete: true,
          manual_ack: false
        }
      }
    }
  end

  it 'use default value for #server' do
    RabbitJobs.config.to_hash.should == {
      error_log: true,
      server: 'amqp://localhost',
      queues: {
        jobs: {
          auto_delete: false,
          exclusive: false,
          durable: true,
          manual_ack: true
        }
      }
    }
  end

  it 'returns settings on some methods' do
    RabbitJobs.config.error_log.should eq true
    RabbitJobs.config.server.should eq 'amqp://localhost'
    RabbitJobs.config.routing_keys.should eq [:jobs]
  end
end
