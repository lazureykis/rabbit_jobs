# -*- encoding : utf-8 -*-
require 'benchmark'

module RabbitJobs
  module Job
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
          ret = nil
          execution_time = Benchmark.measure { ret = perform(*params) }
          RabbitJobs.logger.info short_message: "Completed: #{self.to_ruby_string}", _execution_time: execution_time.to_s.strip
        rescue ScriptError, StandardError
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

            begin
              case proc.arity
              when 0
                proc.call()
              when 1
                proc.call(error)
              else
                proc.call(error, *params)
              end
            rescue
              RJ.logger.error($!)
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

      def expires_at_expired?
        expires_at = opts['expires_at'].to_i
        return false if expires_at == 0
        Time.now.to_i > expires_at
      end

      def expires_in_expired?
        exp_in = self.expires_in.to_i
        created_at = opts['created_at'].to_i
        return false if exp_in == 0 || created_at == 0

        Time.now.to_i > created_at + exp_in
      end

      def expired?
        expires_at_expired? || expires_in_expired?
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
        RabbitJobs.logger.error(short_message: error.message,
          _job: self.to_ruby_string, _exception: error.class, full_message: error.backtrace.join("\r\n"))

        Airbrake.notify(error, session: {args: self.to_ruby_string}) if defined?(Airbrake)
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
          raise ArgumentError.new("Pass proc or symbol to on_error hook") unless proc_or_symbol && ( proc_or_symbol.is_a?(Proc) || proc_or_symbol.is_a?(Symbol) )
          @rj_on_error_hooks ||= []
          @rj_on_error_hooks << proc_or_symbol
        end
      end

      def queue(routing_key)
        raise ArgumentError.new("routing_key is nil") unless routing_key.present?
        @rj_queue = routing_key.to_sym
      end

      def perform_async(*args)
        RJ::Publisher.publish_to(@rj_queue || RJ.config.default_queue, self, *args)
      end

      def perform(*params)
        new.perform(*params)
      end
    end

    def self.parse(payload)
      begin
        encoded = JSON.parse(payload)
        job_klass = encoded['class'].to_s.constantize
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

    def self.serialize(klass_name, *params)
      {
        'class' => klass_name.to_s,
        'opts' => {'created_at' => Time.now.to_i},
        'params' => params
      }.to_json
    end
  end
end
