# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::ErrorMailer do
  describe '#report_error' do
    it 'logs error raised in #send_letter' do
      mock(RabbitJobs::ErrorMailer).enabled? { true }
      mock(RabbitJobs::ErrorMailer).send_letter(anything, anything) { raise 'hello' }

      mock(RabbitJobs.logger).error(anything)
      RabbitJobs::ErrorMailer.report_error(TestJob.new, StandardError.new)
    end
  end
end
