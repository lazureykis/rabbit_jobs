# -*- encoding : utf-8 -*-

require 'rabbit_jobs/version'
require 'rabbit_jobs/configuration'
require 'rabbit_jobs/logger'
require 'rabbit_jobs/publisher'
require 'rabbit_jobs/worker'

module RabbitJobs
  extend self

  def enqueue(klass, *params)
    RabbitJobs::Publisher.enqueue(klass, params)
  end

  def enqueue_to(routing_key, klass, *params)
    RabbitJobs::Publisher.enqueue_to(routing_key, params)
  end
end