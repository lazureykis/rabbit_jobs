require 'benchmark'

module RabbitJobs
  module Job
    attr_accessor :created_at

    def expired?
      exp_in = self.class.expires_in.to_i
      return false if exp_in == 0 || created_at == nil

      Time.now.to_i > created_at + exp_in
    end

    def run_perform(*params)
      ret = nil
      execution_time = Benchmark.measure { ret = perform(*params) }
      RabbitJobs.logger.info(
        short_message: "Completed: #{to_ruby_string(*params)}",
        _execution_time: execution_time.to_s.strip)
    rescue ScriptError, StandardError
      log_job_error($ERROR_INFO, *params)
      run_on_error_hooks($ERROR_INFO, *params)
    end

    def run_on_error_hooks(error, *params)
      return unless @@rj_on_error_hooks.try(:present?)

      @@rj_on_error_hooks.each do |proc_or_symbol|
        proc = if proc_or_symbol.is_a?(Symbol)
                 method(proc_or_symbol)
               else
                 proc_or_symbol
               end

        begin
          case proc.arity
          when 0
            proc.call
          when 1
            proc.call(error)
          else
            proc.call(error, *params)
          end
        rescue
          RJ.logger.error($ERROR_INFO)
        end
      end
    end

    def to_ruby_string(*params)
      rs = self.class.name + params_string(*params)
      rs << ", created_at: #{created_at}" if created_at
      rs
    end

    def params_string(*params)
      if params.count > 0
        "(#{params.map(&:to_s).join(', ')})"
      else
        ''
      end
    end

    def log_job_error(error, *params)
      RabbitJobs.logger.error(
        short_message: (error.message.presence || 'rj_worker job error'),
        _job: to_ruby_string,
        _exception: error.class,
        full_message: error.backtrace.join("\r\n"))

      Airbrake.notify(error, session: { args: to_ruby_string(*params) }) if defined?(Airbrake)
    end

    class << self
      def parse(payload)
        encoded = JSON.parse(payload)
        job_klass = encoded['class'].to_s.constantize
        job = job_klass.new
        job.created_at = encoded['created_at']
        [job, encoded['params']]
      rescue NameError
        [:not_found, encoded['class']]
      rescue JSON::ParserError
        [:parsing_error, payload]
      rescue
        [:error, $ERROR_INFO, payload]
      end

      def serialize(klass_name, *params)
        {
          'class' => klass_name.to_s,
          'created_at' => Time.now.to_i,
          'params' => params
        }.to_json
      end

      def included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # DSL method for jobs
        def expires_in(seconds = nil)
          @expires_in = seconds.to_i if seconds
          @expires_in
        end

        def on_error(*hooks)
          @rj_on_error_hooks ||= []
          hooks.each do |proc_or_symbol|
            raise ArgumentError.new("Pass proc or symbol to on_error hook") unless proc_or_symbol && ( proc_or_symbol.is_a?(Proc) || proc_or_symbol.is_a?(Symbol) )
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
    end
  end
end
