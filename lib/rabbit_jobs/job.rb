# -*- encoding : utf-8 -*-
require 'json'
require 'digest/md5'

module RabbitJobs::Job
  extend RabbitJobs::Helpers
  extend RabbitJobs::Logger
  extend self

  def self.included(base)
    include RabbitJobs::Logger
    base.extend (ClassMethods)

    def initialize(*perform_params)
      self.klass = self.class
      self.params = *perform_params
    end

    attr_accessor :params, :klass, :child_pid

    def perform
      if @child_pid = fork
        srand # Reseeding
        log "Forked #{@child_pid} at #{Time.now} to process #{self.class}.perform(#{ params.map(&:inspect).join(', ') })"
        Process.wait(@child_pid)
        yield if block_given?
      else
        begin
          # log 'before perform'
          self.class.perform(*params)
          # log 'after perform'
        rescue
          puts $!.inspect
        end
        exit!
      end
    end

    def payload
      ([klass.to_s] + params).to_json
    end

  #   def locked
  #     self.class.rj_lock_type
  #   end

  #   def locked?
  #     !!self.locked
  #   end

  #   # lock_key is a hash for locking enqueued job in redis
  #   def lock_key
  #     case locked
  #     when :with_params
  #       Digest::MD5.hexdigest([self.class, self.params].to_json)
  #     when :without_params
  #       Digest::MD5.hexdigest(self.class)
  #     when nil
  #       ""
  #     else raise NotImplementedError
  #     end
  #   end
  end

  module ClassMethods
    # attr_accessor :rj_lock_type

    # def locked(lock_type)
    #   @rj_lock_type = lock_type
    # end
  end

  def self.parse(payload)
    begin
      params = JSON.parse(payload)
      klass = constantize(params.delete_at(0))
      job = klass.new(*params)
    rescue
      log "JOB INIT ERROR at #{Time.now.to_s}:"
      log $!.inspect
      log $!.backtrace
      log "message: #{payload.inspect}"
      # Mailer.send(klass_name, params, $!)
      # raise $!
    end
  end
end