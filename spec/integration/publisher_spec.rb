# -*- encoding : utf-8 -*-
require 'spec_helper'
require 'json'
require 'benchmark'

describe RabbitJobs::Publisher do

  before(:each) do
    RabbitJobs.configure do |c|
      c.url 'amqp://localhost/'
      c.exchange 'test'
      c.queue 'rspec_queue'
      c.queue 'rspec_queue2'
      c.queue 'rspec_queue3'
    end

    RabbitJobs::Publisher.purge_queue(:rspec_queue, :rspec_queue2, :rspec_queue3)
  end

  it 'should publish message to queue' do
    RabbitJobs.publish(TestJob, 'some', 'other', 'params')
    RabbitJobs::Publisher.purge_queue('rspec_queue').should == 1
  end

  it 'should accept symbol as queue name' do
    RabbitJobs.publish_to(:rspec_queue, TestJob)
    RabbitJobs::Publisher.purge_queue('rspec_queue').should == 1
  end

  it 'purge_queue should accept many queues' do
    RabbitJobs.publish_to(:rspec_queue, TestJob)
    RabbitJobs.publish_to(:rspec_queue2, TestJob)
    RabbitJobs.publish_to(:rspec_queue3, TestJob)
    RabbitJobs::Publisher.purge_queue(:rspec_queue, :rspec_queue2, :rspec_queue3).should == 3
  end

  it 'should publish job with *params' do
    RabbitJobs.publish_to(:rspec_queue, JobWithArgsArray, 'first value', :some_symbol, 123, 'and string')
    RabbitJobs::Publisher.purge_queue(:rspec_queue).should == 1
  end

  it 'should publish 1000 messages in one second' do
    time = Benchmark.measure {
      1000.times { RabbitJobs.publish_to(:rspec_queue, TestJob) }
    }
    RabbitJobs::Publisher.purge_queue(:rspec_queue, :rspec_queue2, :rspec_queue3).should == 1000
    puts time
  end
end