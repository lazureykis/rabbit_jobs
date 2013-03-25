# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Worker do
  it 'should listen for messages' do
    RabbitJobs.configure do |c|
      c.server 'amqp://localhost/rj'
      c.prefix 'test_durable'
      c.queue 'rspec_durable_queue', auto_delete: false, durable: true, ack: true
    end

    RJ::Publisher.purge_queue('rspec_durable_queue')
    count = 5
    5.times {
      RabbitJobs.publish_to(:rspec_durable_queue, PrintTimeJob, Time.now)
    }

    Timecop.freeze(Time.now - 4600) {
      5.times { RabbitJobs.publish_to(:rspec_durable_queue, JobWithExpire) }
    }

    RabbitJobs.publish_to(:rspec_durable_queue, JobWithErrorHook)

    worker = RabbitJobs::Worker.new
    RJ.logger.level = Logger::FATAL

    mock(PrintTimeJob).perform(anything).times(5)
    mock(JobWithErrorHook).perform
    dont_allow(JobWithExpire).perform
    worker.work(1) # work for 1 second
    RJ::Publisher.purge_queue('rspec_durable_queue')
  end

  it 'should allow to publish jobs from worker' do
    RabbitJobs.configure do |c|
      c.server 'amqp://localhost/rj'
      c.prefix 'test_durable'
      c.queue 'rspec_durable_queue', auto_delete: false, durable: true, ack: true
    end

    RJ::Publisher.purge_queue('rspec_durable_queue')
    RabbitJobs.publish_to(:rspec_durable_queue, JobWithPublish, 1)

    worker = RabbitJobs::Worker.new
    # mock(RJ).publish_to(:rspec_durable_queue, JobWithPublish, 5)
    worker.work(3) # work for 1 second
  end
end