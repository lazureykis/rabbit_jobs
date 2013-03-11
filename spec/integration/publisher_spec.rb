# -*- encoding : utf-8 -*-
require 'spec_helper'
require 'json'
require 'benchmark'

describe RabbitJobs::Publisher do

  before(:each) do
    RabbitJobs.configure do |c|
      c.server 'amqp://localhost/'
      c.queue 'rspec_queue'
      c.queue 'rspec_queue2'
      c.queue 'rspec_queue3'
    end

    RJ.purge_queue(:rspec_queue, :rspec_queue2, :rspec_queue3)
  end

  it 'should publish message to queue' do
    RJ.publish(TestJob, 'some', 'other', 'params')
    RJ.purge_queue('rspec_queue').should == 1
  end

  it 'should accept symbol as queue name' do
    RJ.publish_to(:rspec_queue, TestJob)
    RJ.purge_queue('rspec_queue').should == 1
  end

  it 'purge_queue should accept many queues' do
    RJ.publish_to(:rspec_queue, TestJob)
    RJ.publish_to(:rspec_queue2, TestJob)
    RJ.publish_to(:rspec_queue3, TestJob)
    RJ.purge_queue(:rspec_queue, :rspec_queue2, :rspec_queue3).should == 3
  end

  it 'should publish job with *params' do
    RJ.publish_to(:rspec_queue, JobWithArgsArray, 'first value', :some_symbol, 123, 'and string')
    RJ.purge_queue(:rspec_queue).should == 1
  end

  it 'should publish 1000 messages in one second' do
    count = 1000
    published = 0
    time = Benchmark.measure {
      count.times {
        RJ.publish_to(:rspec_queue, TestJob)
      }
      removed = RJ.purge_queue(:rspec_queue, :rspec_queue2, :rspec_queue3)
      removed.should == 1000
    }
    puts time
  end
end