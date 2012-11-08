# -*- encoding : utf-8 -*-
require 'spec_helper'
require 'timecop'
require 'eventmachine'

describe RabbitJobs::Worker do
  it 'should listen for messages' do
    RabbitJobs.configure do |c|
      c.prefix 'test_durable'
      c.queue 'rspec_durable_queue', auto_delete: false, durable: true, ack: true
    end

    RJ::Publisher.purge_queue('rspec_durable_queue')

    5.times { RabbitJobs.publish(PrintTimeJob, Time.now) }
    Timecop.freeze(Time.now - 4600) { 5.times { RabbitJobs.publish(JobWithExpire) } }
    1.times { RabbitJobs.publish(JobWithErrorHook) }
    worker = RabbitJobs::Worker.new

    worker.work(1) # work for 1 second
    RJ::Publisher.purge_queue('rspec_durable_queue')
  end

  it 'should allow to publish jobs from worker' do
    RabbitJobs.configure do |c|
      c.prefix 'test_durable'
      c.queue 'rspec_durable_queue', auto_delete: false, durable: true, ack: true
    end

    RJ::Publisher.purge_queue('rspec_durable_queue')

    RabbitJobs.publish(JobWithPublish)
    worker = RabbitJobs::Worker.new

    worker.work(1) # work for 1 second
  end
end