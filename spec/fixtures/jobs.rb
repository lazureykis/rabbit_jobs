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

class JobWithExpire
  include RabbitJobs::Job
  expires_in 60*60 # expires in 1 hour
  def self.perform

  end
end

class ExpiredJob
  include RabbitJobs::Job

  def self.perform

  end
end

class JobWithErrorHook
  include RabbitJobs::Job
  on_error :first_hook, lambda { puts "second hook" }, :last_hook

  def first_hook(error)
    puts 'first hook'
  end

  def last_hook(error)
    puts 'last hook'
  end

  def self.perform
    raise "Job raised an error at #{Time.now}"
  end
end