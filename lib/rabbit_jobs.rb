# -*- encoding : utf-8 -*-

require 'rabbit_jobs/version'

require 'rabbit_jobs/util'
require 'rabbit_jobs/helpers'
require 'rabbit_jobs/amqp_helper'
require 'rabbit_jobs/configuration'
require 'rabbit_jobs/error_mailer'

require 'rabbit_jobs/job'
require 'rabbit_jobs/publisher'
require 'rabbit_jobs/worker'
require 'rabbit_jobs/scheduler'

require 'logger'

module RabbitJobs
  extend self

  def start
    raise unless block_given?

    AMQP.start {
      AmqpHelper.prepare_connection
      yield
    }
  end

  alias_method :run, :start

  def stop
    if AMQP.connection
      AMQP.connection.disconnect {
        EM.stop
        yield if block_given?
      }
    else
      EM.stop
      yield if block_given?
    end
  end

  def publish(klass, *params, &block)
    RabbitJobs::Publisher.publish(klass, *params, &block)
  end

  def publish_to(routing_key, klass, *params, &block)
    RabbitJobs::Publisher.publish_to(routing_key, klass, *params, &block)
  end

  attr_writer :logger
  def logger
    @logger ||= Logger.new $stdout
  end
end

RJ = RabbitJobs