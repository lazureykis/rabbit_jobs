# -*- encoding : utf-8 -*-
require 'spec_helper'
require 'json'

describe RabbitJobs::Publisher do

  extend RabbitJobs::Locks

  before(:each) do
    queue_name = 'test'
    RabbitJobs.configure do |c|
      c.exchange 'test'
      c.queue 'rspec_queue'
    end
  end

  it 'should publish message to queue' do
    RabbitJobs.enqueue(TestJob, 'some', 'other', 'params')
    RabbitJobs::Publisher.purge_queue('rspec_queue').should == 1
    RabbitJobs::Locks.remove_lock(TestJob.new('some', 'other', 'params'))
  end

  it 'should publish only one message to queue with lock' do
    RabbitJobs.configure do |c|
      c.exchange 'test'
      c.queue 'rspec_queue'
    end

    3.times { RabbitJobs.enqueue(TestJobLockedWithParams, 'some', 'other', 'params') }
    RabbitJobs::Publisher.purge_queue('rspec_queue').should == 1
    RabbitJobs::Locks.remove_lock(TestJobLockedWithParams.new('some', 'other', 'params'))
  end
end