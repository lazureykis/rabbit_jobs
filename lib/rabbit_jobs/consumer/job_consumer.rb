# -*- encoding : utf-8 -*-
module RabbitJobs
  module Consumer
    class JobConsumer
      def process_message(delivery_info, properties, payload)
        job, *error_args = RJ::Job.parse(payload)

        if job.is_a?(Symbol)
          report_error(job, *error_args)
          # case @job
          # when :not_found
          # when :parsing_error
          # when :error
          # end
        else
          if job.expired?
            RJ.logger.warn "Job expired: #{job.to_ruby_string}"
            false
          else
            job.run_perform
          end
        end

        true
      end
    end

    def log_error(msg)
      RJ.logger.error msg
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
        log_error ex.message
        log_error _cleanup_backtrace(ex.backtrace).join("\n")
        log_error "Data received: #{payload.inspect}"
      end
    end
  end
end