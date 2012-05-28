# -*- encoding : utf-8 -*-
require 'json'
require 'digest/md5'

module RabbitJobs::Job
  extend RabbitJobs::Helpers
  extend self

  def self.included(base)
    base.extend (ClassMethods)

    def initialize(*perform_params)
      self.params = perform_params
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
        $0 = "##{@child_pid} #{self.class}.perform(#{ params.map(&:inspect).join(', ') }) #{$0}"
        begin
          if defined?(ActiveRecord::Base)
            ActiveRecord::Base.establish_connection
          end
          if defined?(MongoMapper)
            MongoMapper.database.connection.connect_to_master
          end

          self.class.perform(*params)
        rescue
          RJ.logger.warn(self.inspect)
          RJ.logger.warn([$!.inspect, $!.backtrace.to_a].join("\n"))
          run_on_error_hooks($!)
          RabbitJobs::ErrorMailer.send(self, $!)
        end
        exit!
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
      job = encoded['params'].count > 0 ? job_klass.new(*encoded['params']) : job_klass.new
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