# -*- encoding : utf-8 -*-

require 'rabbit_jobs/version'

require 'rabbit_jobs/helpers'
require 'rabbit_jobs/amqp_helpers'
require 'rabbit_jobs/configuration'
require 'rabbit_jobs/logger'

require 'rabbit_jobs/job'
require 'rabbit_jobs/publisher'
require 'rabbit_jobs/worker'
require 'rabbit_jobs/scheduler'

module RabbitJobs
  extend self

  def publish(klass, opts = {}, *params)
    RabbitJobs::Publisher.publish(klass, opts, *params)
  end

  def publish_to(routing_key, klass, opts = {}, *params)
    RabbitJobs::Publisher.publish_to(routing_key, klass, opts, *params)
  end
end

module RJ
  include RabbitJobs
end