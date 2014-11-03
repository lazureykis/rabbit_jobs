module RabbitJobs
  module Consumer
    # Default consumer.
    class JobConsumer
      def process_message(_delivery_info, _properties, payload)
        job, params = RJ::Job.parse(payload)

        if job.is_a?(Symbol)
          report_error(job, *params)
        else
          if job.expired?
            RJ.logger.warn "Job expired: #{job.to_ruby_string(*params)}"
          else
            job.run_perform(*params)
          end
        end
        true
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
