# -*- encoding : utf-8 -*-
module RabbitJobs
  class ErrorMailer
    def self.enabled?
      defined?(ActionMailer) && !!RabbitJobs.config.mail_errors_from && !RabbitJobs.config.mail_errors_from.empty?
    end

    def self.report_error(job, error = $!)
      return unless enabled?

      params ||= []

      params_str = job.params == [] ? '' : job.params.map { |p| p.inspect }.join(', ')
      subject = "RJ:Worker: #{error.class} on #{job.class}"
      text    = "\n#{job.class}.perform(#{params_str})\n"
      text   += "\n#{error.inspect}\n"
      text   += "\nBacktrace:\n#{error.backtrace.join("\n")}" if error.backtrace

      letter         = ActionMailer::Base.mail
      letter.from    = RabbitJobs.config.mail_errors_from
      letter.to      = RabbitJobs.config.mail_errors_to
      letter.subject = subject
      letter.body    = text

      begin
        letter.deliver
      rescue
        RJ.logger.error [$!.message, $!.backtrace].flatten.join("\n")
      end
    end
  end
end