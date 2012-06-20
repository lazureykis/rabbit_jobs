# -*- encoding : utf-8 -*-

require 'rabbit_jobs/version'

require 'rabbit_jobs/util'
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

  def after_fork(&block)
    raise ArgumentError.new("No block passed to after_fork") unless block_given?
    @@after_fork_callbacks ||= []

    @@after_fork_callbacks << block
  end

  def __after_fork_callbacks
    @@after_fork_callbacks ||= []
  end
end

RJ = RabbitJobs