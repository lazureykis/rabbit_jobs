# -*- encoding : utf-8 -*-
require 'logger'
require 'rake'

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
require 'rabbit_jobs/tasks'

module RabbitJobs
  extend self

  def start
    raise unless block_given?
    raise if EM.reactor_running?

    EM.run {
      AmqpHelper.prepare_connection
      yield
    }
  end

  alias_method :run, :start

  def stop
    if AMQP.connection
      AMQP.connection.disconnect {
        AMQP.connection = nil
        AMQP.channel = nil
        EM.stop {
          yield if block_given?
        }
      }
    else
      EM.stop {
        yield if block_given?
      }
    end
  end

  def running?
    EM.reactor_running?
  end

  def publish(klass, *params, &block)
    if RJ.running?
      RJ::Publisher.publish(klass, *params, &block)
    else
      RJ.run {
        RJ::Publisher.publish(klass, *params) {
          RJ.stop {
            yield if block_given?
          }
        }
      }
    end
  end

  def publish_to(routing_key, klass, *params, &block)
    if RJ.running?
      RJ::Publisher.publish_to(routing_key, klass, *params, &block)
    else
      RJ.run {
        RJ::Publisher.publish_to(routing_key, klass, *params) {
          RJ.stop {
            yield if block_given?
          }
        }
      }
    end
  end

  def direct_publish_to(routing_key, payload, ex = {}, &block)
    if RJ.running?
      RJ::Publisher.direct_publish_to(routing_key, payload, ex, &block)
    else
      RJ.run {
        RJ::Publisher.direct_publish_to(routing_key, payload, ex) {
          RJ.stop {
            yield if block_given?
          }
        }
      }
    end
  end

  def purge_queue(*routing_keys, &block)
    if RJ.running?
      RJ::Publisher.purge_queue(*routing_keys, &block)
    else
      messages_count = 0
      RJ.run {
        RJ::Publisher.purge_queue(*routing_keys) { |count|
          messages_count = count
          RJ.stop {
            yield(count) if block_given?
          }
        }
      }
      messages_count
    end
  end

  attr_writer :logger
  def logger
    unless @logger
      @logger = Logger.new($stdout)
      @logger.level = Logger::WARN
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
end

RJ = RabbitJobs