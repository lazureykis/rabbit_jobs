# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Worker do

  before(:each) do
    RJ.configure do |c|
      c.server 'amqp://localhost'
      c.queue "default"
    end
  end

  let(:worker) { RJ::Worker.new(:default) }

  describe '#consumer' do
    it 'validates consumer type' do
      old_consumer = worker.consumer
      lambda { worker.consumer = 123 }.should raise_error
      worker.consumer.should == old_consumer

      new_consumer = TestConsumer.new
      lambda { worker.consumer = new_consumer }.should_not raise_error
      worker.consumer.should == new_consumer
    end
  end
end