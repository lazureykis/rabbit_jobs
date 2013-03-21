# -*- encoding : utf-8 -*-
module RabbitJobs
  module Consumer
    class JobConsumer
      def process_message(delivery_info, properties, payload)
        job = RJ::Job.parse(payload)

        if job.is_a?(Symbol)
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
  end
end