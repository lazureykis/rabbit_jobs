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
    RJ.purge_queue('default').should == 0
  end
end
