# -*- encoding : utf-8 -*-

class TestJob
  include RJ::Job
end

class PrintTimeJob
  include RJ::Job

  def self.perform(time)
    puts "Running job queued at #{time}"
  end
end

class JobWithExpire
  include RJ::Job
  expires_in 60*60 # expires in 1 hour
  def self.perform

  end
end

class ExpiredJob
  include RJ::Job

  def self.perform

  end
end

class JobWithErrorHook
  include RJ::Job
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

class JobWithArgsArray
  include RJ::Job

  def perform(first_param, *other_args)
    puts "#{self.class.name}.perform called with first_param: #{first_param.inspect} and other_args: #{other_args.inspect}"
  end
end