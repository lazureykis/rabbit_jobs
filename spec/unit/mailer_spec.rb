# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::ErrorMailer do
  describe '#enabled?' do
    it 'should be enabled when use setup email' do
      RabbitJobs::ErrorMailer.enabled?.should == false
      RabbitJobs.configure do |c|
        c.mail_errors_to 'dev@example.com'
        c.mail_errors_from 'app@example.com'
      end

      RabbitJobs::ErrorMailer.enabled?.should == true
    end
  end

  describe '#send' do
    it 'should send email with error' do
      email = ActionMailer::Base.mail
      mock(ActionMailer::Base).mail { email }
      mock(email).deliver { }
      mock(RabbitJobs::ErrorMailer).enabled? { true }

      RabbitJobs::ErrorMailer.report_error(TestJob.new, RuntimeError.new('error text'))
    end
  end
end
