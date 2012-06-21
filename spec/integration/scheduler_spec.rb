# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Scheduler do
  it 'should start with config.yml' do
    scheduler = RabbitJobs::Scheduler.new
    scheduler.schedule = YAML.load_file(File.expand_path('../../fixtures/schedule.yml', __FILE__))

    scheduler.pidfile = '/tmp/rj_scheduler.pid'
    scheduler.background = false

    scheduler.work(10) # work for 1 second

    RJ.config.queue 'default', RJ::Configuration::DEFAULT_QUEUE_PARAMS
    puts "messages queued: " + RabbitJobs::Publisher.purge_queue('default').to_s
    RabbitJobs::Publisher.purge_queue('default').should == 0
  end
end