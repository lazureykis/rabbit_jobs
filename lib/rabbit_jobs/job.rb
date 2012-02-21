# -*- encoding : utf-8 -*-
require 'json'
require 'digest/md5'

module RabbitJobs::Job
  extend RabbitJobs::Helpers
  extend self

  def self.included(base)
    base.extend (ClassMethods)

    def initialize(*perform_params)
      self.params = *perform_params
      self.opts = {}
    end

    attr_accessor :params, :opts, :child_pid

    def run_perform
      if @child_pid = fork
        srand # Reseeding
        RJ.logger.info "Forked #{@child_pid} at #{Time.now} to process #{self.class}.perform(#{ params.map(&:inspect).join(', ') })"
        Process.wait(@child_pid)
        yield if block_given?
      else
        begin
          if defined?(ActiveRecord::Base)
            ActiveRecord::Base.establish_connection
          end
          if defined?(MongoMapper)
            MongoMapper.database.connection.connect_to_master
          end
          # RJ.logger.debug 'before perform'
          self.class.perform(*params)
          # RJ.logger.debug 'after perform'
        rescue
          RJ.logger.warn($!.inspect)
          RabbitJobs::ErrorMailer.send(self, $!)

          run_on_error_hooks($!)
        end
        exit!
      end
    end

    def run_on_error_hooks(error)
      if self.class.rj_on_error_hooks
        self.class.rj_on_error_hooks.each do |proc_or_symbol|
          if proc_or_symbol.is_a?(Symbol)
            self.send(proc_or_symbol, error, *params)
          else
            case proc_or_symbol.arity
            when 0
              proc_or_symbol.call()
            when 1
              proc_or_symbol.call(error)
            else
              proc_or_symbol.call(error, *params)
            end
          end
        end
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
      self.expires_in && self.expires_in > 0
    end

    def expired?
      if self.opts['expires_at']
        Time.now.to_i > opts['expires_at'].to_i
      elsif expires? && opts['created_at']
        Time.now.to_i > (opts['created_at'].to_i + expires_in.to_i)
      else
        false
      end
    end
  end

  module ClassMethods
    attr_accessor :rj_expires_in, :rj_on_error_hooks

    # DSL method for jobs
    def expires_in(seconds)
     @rj_expires_in = seconds.to_i
    end

    def on_error(*hooks)
      hooks.each do |proc_or_symbol|
        raise ArgumentError unless proc_or_symbol && ( proc_or_symbol.is_a?(Proc) || proc_or_symbol.is_a?(Symbol) )
        @rj_on_error_hooks ||= []
        @rj_on_error_hooks << proc_or_symbol
      end
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
      RJ.logger.error "JOB INIT ERROR at #{Time.now.to_s}:"
      RJ.logger.error $!.inspect
      RJ.logger.error $!.backtrace
      RJ.logger.error "message: #{payload.inspect}"
      # Mailer.send(klass_name, params, $!)
      # raise $!
    end
  end
end