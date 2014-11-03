require 'spec_helper'
require 'json'
require 'benchmark'

describe RabbitJobs::Publisher do

  before(:each) do
    RabbitJobs.configure do |c|
      c.server 'amqp://localhost/rj'
      c.queue 'rspec_queue'
      c.queue 'rspec_queue2'
      c.queue 'rspec_queue3'
    end

    RJ.purge_queue(:rspec_queue, :rspec_queue2, :rspec_queue3)
  end

  it 'should publish message to queue' do
    RJ.publish_to(:rspec_queue, TestJob, 'some', 'other', 'params')
    RJ.queue_status('rspec_queue')[:message_count].to_i.should == 1
    RJ.purge_queue('rspec_queue')
    RJ.queue_status('rspec_queue')[:message_count].to_i.should == 0
  end

  it 'should accept symbol as queue name' do
    RJ.publish_to(:rspec_queue, TestJob)
    RJ.queue_status('rspec_queue')[:message_count].to_i.should == 1
    RJ.purge_queue('rspec_queue')
    RJ.queue_status('rspec_queue')[:message_count].to_i.should == 0
  end

  it 'purge_queue should accept many queues' do
    RJ.publish_to(:rspec_queue, TestJob)
    RJ.publish_to(:rspec_queue2, TestJob)
    RJ.publish_to(:rspec_queue3, TestJob)
    RJ.queue_status('rspec_queue')[:message_count].to_i.should == 1
    RJ.queue_status('rspec_queue2')[:message_count].to_i.should == 1
    RJ.queue_status('rspec_queue3')[:message_count].to_i.should == 1
    RJ.purge_queue(:rspec_queue, :rspec_queue2, :rspec_queue3)
    RJ.queue_status('rspec_queue')[:message_count].to_i.should == 0
    RJ.queue_status('rspec_queue2')[:message_count].to_i.should == 0
    RJ.queue_status('rspec_queue3')[:message_count].to_i.should == 0
  end

  it 'should publish job with *params' do
    RJ.publish_to(:rspec_queue, JobWithArgsArray, 'first value', :some_symbol, 123, 'and string')
    RJ.queue_status('rspec_queue')[:message_count].to_i.should == 1
    RJ.purge_queue(:rspec_queue)
    RJ.queue_status('rspec_queue')[:message_count].to_i.should == 0
  end

  it 'should publish 1000 messages in one second' do
    count = 1000
    time = Benchmark.measure do
      count.times { RJ.publish_to(:rspec_queue, TestJob) }
      to_remove = RJ.queue_status('rspec_queue')[:message_count].to_i
      to_remove += RJ.queue_status('rspec_queue2')[:message_count].to_i
      to_remove += RJ.queue_status('rspec_queue3')[:message_count].to_i
      to_remove.should == count

      RJ.purge_queue(:rspec_queue, :rspec_queue2, :rspec_queue3)

      remains = RJ.queue_status('rspec_queue')[:message_count].to_i
      remains += RJ.queue_status('rspec_queue2')[:message_count].to_i
      remains += RJ.queue_status('rspec_queue3')[:message_count].to_i
      remains.should == 0
    end
    puts time
  end
end
