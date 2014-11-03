require 'spec_helper'

describe RabbitJobs::Scheduler do
  it 'should start with config.yml' do
    scheduler = RabbitJobs::Scheduler.new
    scheduler.schedule = YAML.load_file(File.expand_path('../../fixtures/schedule.yml', __FILE__))

    # stop scheduler after 3 seconds
    Thread.start do
      sleep 3
      scheduler.shutdown
    end
    scheduler.work

    RJ.config.queue 'default', RJ::Configuration::DEFAULT_QUEUE_PARAMS
    puts "messages queued: #{RJ.purge_queue('default')}"
    RJ.queue_status('default')[:message_count].to_i.should == 0
    RJ.purge_queue('default')
  end
end
