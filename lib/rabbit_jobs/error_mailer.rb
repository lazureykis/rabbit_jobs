# -*- encoding : utf-8 -*-
module RabbitJobs
  class ErrorMailer
    class << self
      def enabled?
        return false unless defined?(ActionMailer)
        config_present = RabbitJobs.config.mail_errors_from &&
                         RabbitJobs.config.mail_errors_to &&
                         RabbitJobs.config.mail_errors_from.size > 0 &&
                         RabbitJobs.config.mail_errors_to.size > 0
        !!config_present
      end

      def send_letter(subject, body)
        letter         = ActionMailer::Base.mail
        letter.from    = RabbitJobs.config.mail_errors_from
        letter.to      = RabbitJobs.config.mail_errors_to
        letter.subject = subject
        letter.body    = body

        letter.deliver
      end

      def report_error(job, error = $!)
        return unless enabled?

        params = job.params || []

        params_str = params.map { |p| p.inspect }.join(', ')
        subject = "RJ:Worker: #{error.class} on #{job.class}"
        text    = "\n#{job.class}.perform(#{params_str})\n"
        text   += "\n#{error.inspect}\n"
        text   += "\nBacktrace:\n#{error.backtrace.join("\n")}" if error.backtrace

        begin
          send_letter(subject, text)
        rescue
          RJ.logger.error [$!.message, $!.backtrace].flatten.join("\n")
        end
      end
    end
  end
end