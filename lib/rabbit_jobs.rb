# -*- encoding : utf-8 -*-
require 'logger'
require 'json'
require 'bunny'
require 'rufus-scheduler'
require 'yaml'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash'
require 'active_support/core_ext/string/inflections'

require 'rabbit_jobs/version'
require 'rabbit_jobs/configuration'
require 'rabbit_jobs/consumer/job_consumer'
require 'rabbit_jobs/job'
require 'rabbit_jobs/publisher'
require 'rabbit_jobs/main_loop'
require 'rabbit_jobs/worker'
require 'rabbit_jobs/scheduler'
require 'rabbit_jobs/tasks'

module RabbitJobs
  extend self

  def publish_to(routing_key, klass, *params)
    Publisher.publish_to(routing_key, klass, *params)
  end

  def direct_publish_to(routing_key, payload, ex = {})
    Publisher.direct_publish_to(routing_key, payload, ex)
  end

  def purge_queue(*routing_keys)
    Publisher.purge_queue(*routing_keys)
  end

  attr_writer :logger
  def logger
    unless @logger
      @logger = Logger.new($stdout)
      @logger.level = Logger::INFO
      @logger.formatter = nil
      @logger.progname = 'rj'
    end
    @logger
  end

  def after_fork(&block)
    raise unless block_given?
    @_after_fork_callbacks ||= []
    @_after_fork_callbacks << block
  end

  def _run_after_fork_callbacks
    @_after_fork_callbacks ||= []
    @_after_fork_callbacks.each { |callback|
      callback.call
    }
  end

  def before_process_message(&block)
    raise unless block_given?
    @before_process_message_callbacks ||= []
    @before_process_message_callbacks << block
  end

  def run_before_process_message_callbacks
    @before_process_message_callbacks ||= []
    @before_process_message_callbacks.each { |callback|
      return false unless callback.call
    }
    return true
  end
end

RJ = RabbitJobs
