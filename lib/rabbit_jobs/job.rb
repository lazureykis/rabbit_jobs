# -*- encoding : utf-8 -*-
require 'json'
require 'digest/md5'

module RabbitJobs::Job
  include RabbitJobs::Helpers
  extend self

  def self.included(base)
    base.extend (ClassMethods)

    def initialize(*perform_params)
      self.params = perform_params
      self.opts = {}
    end

    attr_accessor :params, :opts

    def run_perform
      begin
        start_time = Time.now
        RJ.logger.info "Started to perform #{self.to_ruby_string}"
        self.class.perform(*params)
        execution_time = Time.now - start_time
        RJ.logger.info "     Job completed #{self.to_ruby_string} in #{execution_time} seconds."
      rescue
        log_job_error($!)
        run_on_error_hooks($!)
      end
    end

    def run_on_error_hooks(error)
      if self.class.rj_on_error_hooks
        self.class.rj_on_error_hooks.each do |proc_or_symbol|
          proc = proc_or_symbol
          if proc_or_symbol.is_a?(Symbol)
            proc = self.method(proc_or_symbol)
          end

          case proc.arity
          when 0
            proc.call()
          when 1
            proc.call(error)
          else
            proc.call(error, *params)
          end
        end
      end
    end

    def payload
      {'class' => self.class.to_s, 'opts' => (self.opts || {}), 'params' => params}.to_json
    end

    def expires_in
      self.class.rj_expires_in
    end

    def expires?
      self.expires_in && self.expires_in > 0
    end

    def expired?
      now = Time.now.to_i
      if self.opts['expires_at']
        now > opts['expires_at'].to_i
      elsif expires? && opts['created_at']
        now > (opts['created_at'].to_i + expires_in.to_i)
      else
        false
      end
    end

    def to_ruby_string
      rs = self.class.name
      rs << params_string
      if opts.count > 0
        rs << ", opts: "
        rs << opts.inspect
      end
    end

    def params_string
      if params.count > 0
        "(#{params.map(&:to_s).join(", ")})"
      else
        ""
      end
    end

    def log_job_error(error)
      RJ.logger.warn error.message
      RJ.logger.warn(self.to_ruby_string)
      RJ.logger.warn _cleanup_backtrace(error.backtrace).join("\n")
      RabbitJobs::ErrorMailer.report_error(self, error) rescue nil
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
    rescue NameError
      [:not_found, encoded['class']]
    rescue JSON::ParserError
      [:parsing_error, payload]
    rescue
      [:error, $!, payload]
    end
  end
end