# -*- encoding : utf-8 -*-
module RabbitJobs
  module Consumer
    class JobConsumer
      def process_message(delivery_info, properties, payload)
        job, *error_args = RJ::Job.parse(payload)

        if job.is_a?(Symbol)
          report_error(job, *error_args)
        else
          if job.expired?
            RJ.logger.warn "Job expired: #{job.to_ruby_string}"
          else
            job.run_perform
          end
        end
        true
      end

      def log_airbrake(msg_or_exception, payload)
        if defined?(Airbrake)
          if msg_or_exception.is_a?(String)
            Airbrake.notify(RuntimeError.new(msg_or_exception))
          else
            Airbrake.notify(msg_or_exception)
          end
        end
      end

      def report_error(error_type, *args)
        case error_type
        when :not_found
          RJ.logger.error "Cannot find job class '#{args.first}'"
        when :parsing_error
          RJ.logger.error "Cannot initialize job. Json parsing error. Data received: #{args.first.inspect}"
        when :error
          ex, payload = args
          RJ.logger.error short_message: ex.message, full_message: ex.backtrace, _payload: payload.inspect
        end
      end
    end
  end
end