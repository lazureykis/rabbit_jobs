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

    RJ.run {
      RJ::Publisher.purge_queue('rspec_durable_queue') {
        count = 5
        5.times {
          RabbitJobs.publish(PrintTimeJob, Time.now) {
            count -= 1
            if count <= 0
              Timecop.freeze(Time.now - 4600) {
                count = 5
                5.times {
                  RabbitJobs.publish(JobWithExpire) {
                    count -= 1
                    if count <= 0
                      RabbitJobs.publish(JobWithErrorHook) {
                        RJ.stop
                      }
                    end
                  }
                }
              }
            end
          }
        }
      }
    }

    worker = RabbitJobs::Worker.new

    worker.work(1) # work for 1 second
    RJ.run { RJ::Publisher.purge_queue('rspec_durable_queue') { RJ.stop } }
  end

  it 'should allow to publish jobs from worker' do
    RabbitJobs.configure do |c|
      c.prefix 'test_durable'
      c.queue 'rspec_durable_queue', auto_delete: false, durable: true, ack: true
    end

    RJ.run {
      RJ::Publisher.purge_queue('rspec_durable_queue') {
        RabbitJobs.publish(JobWithPublish) {
          RJ.stop
        }
      }
    }

    worker = RabbitJobs::Worker.new

    worker.work(1) # work for 1 second
  end
end