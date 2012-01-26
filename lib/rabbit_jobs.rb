# -*- encoding : utf-8 -*-

require 'rabbit_jobs/version'

require 'rabbit_jobs/helpers'
require 'rabbit_jobs/amqp_helpers'
require 'rabbit_jobs/configuration'
require 'rabbit_jobs/logger'

require 'rabbit_jobs/job'
require 'rabbit_jobs/publisher'
require 'rabbit_jobs/worker'

module RabbitJobs
  extend self

  def enqueue(klass, *params)
    RabbitJobs::Publisher.enqueue(klass, *params)
  end

  def enqueue_to(routing_key, klass, *params)
    RabbitJobs::Publisher.enqueue_to(routing_key, klass, *params)
  end

  class TestJob < RabbitJobs::Job
    def self.perform(*params)
      puts "processing in job: " + params.inspect
    end
  end
end