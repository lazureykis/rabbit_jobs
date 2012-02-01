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
      self.params = *perform_params
      self.opts = {}
    end

    attr_accessor :params, :opts, :child_pid

    def run_perform
      if @child_pid = fork
        srand # Reseeding
        RabbitJobs::Logger.log "Forked #{@child_pid} at #{Time.now} to process #{self.class}.perform(#{ params.map(&:inspect).join(', ') })"
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
      {'class' => self.class.to_s, 'opts' => (self.opts || {}), 'params' => params}.to_json
      # ([self.class.to_s] + params).to_json
    end

    def expires_in
      self.class.rj_expires_in
    end

    def expires?
      !!self.expires_in
    end

    def expired?
      if self.opts['expires_at']
        Time.now > Time.new(opts['expires_at'])
      elsif expires? && opts['created_at']
        Time.now > (Time.new(opts['created_at']) + expires_in)
      else
        false
      end
    end
  end

  module ClassMethods
    attr_accessor :rj_expires_in

    # DSL method for jobs
    def expires_in(seconds)
     @rj_expires_in = seconds
    end
  end

  def self.parse(payload)
    begin
      encoded = JSON.parse(payload)
      job_klass = constantize(encoded['class'])
      job = job_klass.new(*encoded['params'])
      job.opts = encoded['opts']
      job
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