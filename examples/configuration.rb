# -*- encoding : utf-8 -*-
require 'bundler/setup'
require 'rabbit_jobs'
require 'json'

RabbitJobs.configure do |c|
  c.server "amqp://localhost/"

  c.queue 'rabbit_jobs_test1', durable: true, auto_delete: false, ack: true, arguments: {'x-ha-policy' => 'all'}
  c.queue 'rabbit_jobs_test2', durable: true, auto_delete: false, ack: true, arguments: {'x-ha-policy' => 'all'}
  c.queue 'rabbit_jobs_test3', durable: true, auto_delete: false, ack: true, arguments: {'x-ha-policy' => 'all'}
end

puts JSON.pretty_generate(RabbitJobs.config.to_hash)
puts JSON.pretty_generate(RabbitJobs.config.queues)

class MyJob < RabbitJobs::Job

  expires_in 60 # dont perform this job after 60 seconds

  def self.perform(time)
    puts "This job was published at #{}"
  end
end

RabbitJobs.publish_to('rabbit_jobs_test1', MyJob, Time.now)