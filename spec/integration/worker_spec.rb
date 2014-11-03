# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Worker do
  it 'should allow to publish jobs from worker' do
    RabbitJobs.configure do |c|
      c.server 'amqp://localhost/rj'
      c.queue 'rspec_durable_queue', auto_delete: false, durable: true, manual_ack: true
    end

    RJ::Publisher.purge_queue('rspec_durable_queue')
    RabbitJobs.publish_to(:rspec_durable_queue, JobWithPublish, 1)

    worker = RabbitJobs::Worker.new
    # mock(RJ).publish_to(:rspec_durable_queue, JobWithPublish, 5)

    # stop worker after 3 seconds
    Thread.start do
      sleep 3
      worker.shutdown
    end

    worker.work
  end
end
