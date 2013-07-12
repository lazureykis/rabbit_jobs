# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Worker do
  it 'should allow to publish jobs from worker' do
    RabbitJobs.configure do |c|
      c.server 'amqp://localhost/rj'
      c.queue 'rspec_durable_queue', auto_delete: false, durable: true, ack: true
    end

    RJ::Publisher.purge_queue('rspec_durable_queue')
    RabbitJobs.publish_to(:rspec_durable_queue, JobWithPublish, 1)

    worker = RabbitJobs::Worker.new
    # mock(RJ).publish_to(:rspec_durable_queue, JobWithPublish, 5)
    worker.work(3) # work for 1 second
  end
end