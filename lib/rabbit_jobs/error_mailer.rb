# -*- encoding : utf-8 -*-
module RabbitJobs
  class ErrorMailer
    class << self
      def enabled?
        defined?(ActionMailer) && config_present?
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

        begin
          subject, text = build_error_message(job, error)
          send_letter(subject, text)
        rescue
          RabbitJobs.logger.error [$!.message, $!.backtrace].flatten.join("\n")
        end
      end

      private

      def build_error_message(job, error)
        params = job.params || []

        params_str = params.map { |p| p.inspect }.join(', ')
        subject = "RJ:Worker: #{error.class} on #{job.class}"
        text    = "\n#{job.class}.perform(#{params_str})\n"
        text   += "\n#{error.inspect}\n"
        text   += "\nBacktrace:\n#{error.backtrace.join("\n")}" if error.backtrace
      end

      def config_present?
        config = RabbitJobs.config
        config.mail_errors_from.present? && config.mail_errors_to.present?
      end
    end
  end
end