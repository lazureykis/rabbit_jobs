# -*- encoding : utf-8 -*-

require 'digest/md5'
require 'redis-namespace'

module RabbitJobs
  module Locks
    extend self
    include Logger

    def remove_lock(job)
      redis.del(job.lock_key)
    end

    def lock_job(job, &block)
      key = job.lock_key

      if redis.setnx(key, Time.now)
        begin
          redis.expire(key, RabbitJobs.config.redis_timeout)
          block.call
        rescue
          redis.del(key)
          log "Cannot enqueue job #{job.class}"
          log $!.inspect
          log $!.backtrace
        end
      else
        log('Already locked this job ' + job.class.name)
      end
    end

    def redis
      @@redis_namespace ||= (RabbitJobs.config.redis_namespace)
      @@redis ||= Redis::Namespace.new(@@redis_namespace, :redis => Redis.new)
    end
  end
end