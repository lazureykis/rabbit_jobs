# -*- encoding : utf-8 -*-

class TestJob
  include RJ::Job
  def perform
  end
end

class PrintTimeJob
  include RJ::Job

  def perform(time)
    puts "Running job queued at #{time}"
  end
end

class JobWithExpire
  include RJ::Job
  expires_in 60*60 # expires in 1 hour
  def perform

  end
end

class ExpiredJob
  include RJ::Job

  def perform

  end
end

class JobWithPublish
  include RJ::Job

  def perform(param = 0)
    if param < 5
      puts "publishing job #{param}"
      RJ.publish_to :rspec_durable_queue, JobWithPublish, param + 1
    else
      puts "processing job #{param}"
    end
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

  def perform
    raise "Job raised an error at #{Time.now}"
  end
end

class JobWithArgsArray
  include RJ::Job

  def perform(first_param, *other_args)
    puts "#{self.class.name}.perform called with first_param: #{first_param.inspect} and other_args: #{other_args.inspect}"
  end
end

class TestConsumer
  def process_message *args
  end
end