# -*- encoding : utf-8 -*-
require 'spec_helper'

require 'eventmachine'
describe RabbitJobs::Worker do
  it 'should listen for messages' do
    RabbitJobs.configure do |c|
      c.exchange 'test_durable', auto_delete: false, durable: true
      c.queue 'rspec_durable_queue', auto_delete: false, durable: true, ack: true
    end

    5.times { RabbitJobs::Publisher.enqueue(PrintTimeJob, Time.now) }
    worker = RabbitJobs::Worker.new

    worker.work(1) # work for 1 second
  end
end