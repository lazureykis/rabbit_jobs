# -*- encoding : utf-8 -*-

class TestJob
  include RabbitJobs::Job
end

class PrintTimeJob
  include RabbitJobs::Job

  def self.perform(time)
    puts "Running job queued at #{time}"
  end
end

class TestJobLockedWithParams
  include RabbitJobs::Job
  locked :with_params
end