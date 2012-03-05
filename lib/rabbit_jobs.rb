# -*- encoding : utf-8 -*-

require 'rabbit_jobs/version'

require 'rabbit_jobs/helpers'
require 'rabbit_jobs/amqp_helpers'
require 'rabbit_jobs/configuration'
require 'rabbit_jobs/error_mailer'

require 'rabbit_jobs/job'
require 'rabbit_jobs/publisher'
require 'rabbit_jobs/worker'
require 'rabbit_jobs/scheduler'

require 'logger'

module RabbitJobs
  extend self

  def publish(klass, *params)
    RabbitJobs::Publisher.publish(klass, *params)
  end

  def publish_to(routing_key, klass, *params)
    RabbitJobs::Publisher.publish_to(routing_key, klass, *params)
  end

  attr_writer :logger
  def logger
    @logger ||= Logger.new $stdout
  end
end

RJ = RabbitJobs