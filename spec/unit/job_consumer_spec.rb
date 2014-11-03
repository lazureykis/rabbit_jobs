require 'spec_helper'

describe RabbitJobs::Consumer::JobConsumer do
  let(:consumer) { RabbitJobs::Consumer::JobConsumer.new }
  let(:job) { TestJob.new }

  describe '#process_message' do
    it 'parses job' do
      payload = RJ::Job.serialize(TestJob)
      mock(RJ::Job).parse(payload) { job }
      consumer.process_message(:delivery_info, :properties, payload)
    end

    it 'reports parsing errors' do
      payload = 'some bad json data'
      mock(consumer).report_error(:parsing_error, payload)
      consumer.process_message(:delivery_info, :properties, payload).should == true
    end

    it 'skips expired jobs' do
      payload = RJ::Job.serialize(TestJob)
      job
      mock(TestJob).new { job }
      mock(job).expired? { true }
      dont_allow(job).run_perform
      consumer.process_message(:delivery_info, :properties, payload)
    end

    it 'executes job.perform' do
      payload = RJ::Job.serialize(TestJob)
      job
      mock(TestJob).new { job }
      mock(job).run_perform
      consumer.process_message(:delivery_info, :properties, payload)
    end
  end

  describe '#report_error' do
    it 'accepts error type :not_found' do
      -> { consumer.report_error(:not_found, 'klass_name') }.should_not raise_error
    end

    it 'accepts error type :parsing_error' do
      -> { consumer.report_error(:parsing_error, 'payload data') }.should_not raise_error
    end

    it 'accepts error type :error' do
      exception = nil
      begin
        fail 'testing'
      rescue RuntimeError => e
        exception = e
      end
      -> { consumer.report_error(:error, exception, 'payload data') }.should_not raise_error
    end
  end
end
