# -*- encoding : utf-8 -*-
module RabbitJobs
  class ErrorMailer
    def self.enabled?
      defined?(ActionMailer) && !!RabbitJobs.config.mail_errors_from && !RabbitJobs.config.mail_errors_from.empty?
    end

    def self.send(job, error = $!)
      return unless enabled?

      raise "You must require action_mailer or turn of error reporting in config." unless defined?(ActionMailer)

      params ||= []

      params_str = job.params == [] ? '' : job.params.map { |p| p.inspect }.join(', ')
      subject = "RJ:Worker: #{error.class} on #{job.class}.perform(#{params_str}) "
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
        RJ.logger.error $!.inspect
      end
    end
  end
end
