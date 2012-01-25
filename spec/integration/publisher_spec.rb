# -*- encoding : utf-8 -*-
require 'spec_helper'
require 'json'

describe RabbitJobs::Configuration do
  it 'should publish message to queue' do
    RabbitJobs.enqueue(Integer, 'some', 'other', 'params')
    RabbitJobs::Publisher.purge_queue('default').should == 1
  end
end