# -*- encoding : utf-8 -*-
require 'spec_helper'
require 'json'

describe RabbitJobs::Publisher do
  it 'should publish message to queue' do

    RabbitJobs.configure do |c|
      # c.host "somehost.lan"
      c.exchange 'test', auto_delete: true
      c.queue 'rspec_queue', auto_delete: true
    end

    RabbitJobs.enqueue(Integer, 'some', 'other', 'params')
    RabbitJobs::Publisher.purge_queue('rspec_queue').should == 1
  end
end