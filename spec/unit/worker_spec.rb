require 'spec_helper'

describe RabbitJobs::Worker do

  before(:each) do
    RJ.configure do |c|
      c.server 'amqp://localhost'
      c.queue 'default'
    end
  end

  let(:worker) { RJ::Worker.new(:default) }

  describe '#consumer' do
    it 'validates consumer type' do
      old_consumer = worker.consumer
      -> { worker.consumer = 123 }.should raise_error
      worker.consumer.should eq old_consumer

      new_consumer = TestConsumer.new
      -> { worker.consumer = new_consumer }.should_not raise_error
      worker.consumer.should eq new_consumer
    end
  end
end
