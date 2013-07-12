# -*- encoding : utf-8 -*-
module RabbitJobs
  module Consumer
    class JobConsumer
      include RabbitJobs::Helpers

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

      def log_error(msg_or_exception, payload = nil)
        if msg_or_exception.is_a?(String)
          RJ.logger.error msg_or_exception
        else
          RJ.logger.error msg_or_exception.message
          RJ.logger.error _cleanup_backtrace(msg_or_exception.backtrace).join("\n")
        end
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
          log_error "Cannot find job class '#{args.first}'"
        when :parsing_error
          log_error "Cannot initialize job. Json parsing error."
          log_error "Data received: #{args.first.inspect}"
        when :error
          ex, payload = args
          log_error "Cannot initialize job."
          log_error ex, payload
          log_error "Data received: #{payload.inspect}"
        end
      end
    end
  end
end