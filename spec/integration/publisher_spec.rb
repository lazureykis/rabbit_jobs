# -*- encoding : utf-8 -*-
require 'spec_helper'
require 'json'
require 'benchmark'

describe RabbitJobs::Publisher do

  before(:each) do
    RabbitJobs.configure do |c|
      c.url 'amqp://localhost'
      c.queue 'rspec_queue'
      c.queue 'rspec_queue2'
      c.queue 'rspec_queue3'
    end

    RJ.run {
      RJ::Publisher.purge_queue(:rspec_queue, :rspec_queue2, :rspec_queue3) {
        RJ.stop
      }
    }
  end

  it 'should publish message to queue' do
    RJ.run {
      RabbitJobs.publish(TestJob, 'some', 'other', 'params') {
        RabbitJobs::Publisher.purge_queue('rspec_queue') { |count|
          count.should == 1
          RJ.stop
        }
      }
    }
  end

  it 'should accept symbol as queue name' do
    RJ.run {
      RabbitJobs.publish_to(:rspec_queue, TestJob) {
        RabbitJobs::Publisher.purge_queue('rspec_queue') { |count|
          count.should == 1
          RJ.stop
        }
      }
    }
  end

  it 'purge_queue should accept many queues' do
    RJ.run {
      RabbitJobs.publish_to(:rspec_queue, TestJob) {
        RabbitJobs.publish_to(:rspec_queue2, TestJob) {
          RabbitJobs.publish_to(:rspec_queue3, TestJob) {
            RabbitJobs::Publisher.purge_queue(:rspec_queue, :rspec_queue2, :rspec_queue3) { |count|
              count.should == 3
              RJ.stop
            }
          }
        }
      }
    }
  end

  it 'should publish job with *params' do
    RJ.run {
      RabbitJobs.publish_to(:rspec_queue, JobWithArgsArray, 'first value', :some_symbol, 123, 'and string') {
        RabbitJobs::Publisher.purge_queue(:rspec_queue) { |count|
          count.should == 1
          RJ.stop
        }
      }
    }
  end

  it 'should publish 1000 messages in one second' do
    time = Benchmark.measure {
      RJ.run {
        count = 1000
        published = 0
        count.times {
          RabbitJobs.publish_to(:rspec_queue, TestJob) {
            published += 1
            if published >= count
              RabbitJobs::Publisher.purge_queue(:rspec_queue, :rspec_queue2, :rspec_queue3) { |count|
                count.should == 1000
                RJ.stop
              }
            end
          }
        }
      }
    }
    puts time
  end
end