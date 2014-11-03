require 'spec_helper'

describe RabbitJobs::Job do
  it 'should parse class and params' do
    job, params = RabbitJobs::Job.parse({ class: 'TestJob', params: [1, 2, 3] }.to_json)
    job.should be_is_a(TestJob)
    params.should == [1, 2, 3]
  end

  it 'understands expires_in option' do
    JobWithExpire.expires_in.should eq 1.hour
  end

  context 'job expiration' do
    it 'should expire job by expires_in option' do
      job = JobWithExpire.new
      job.created_at = 2.hours.ago.to_i
      job.expired?.should == true
    end

    it 'should expire job by expires_in option in job class and current_time' do
      job = JobWithExpire.new
      job.created_at = (Time.now - JobWithExpire.expires_in - 10).to_i
      job.expired?.should == true
    end

    it 'should not be expired with default params' do
      job = TestJob.new
      job.created_at = (Time.now).to_i
      job.expired?.should == false
    end
  end
end
