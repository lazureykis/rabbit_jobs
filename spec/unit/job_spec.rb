# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Job do
  it 'should parse class and params' do
    job = RabbitJobs::Job.parse({class: 'TestJob', params: [1,2,3]}.to_json)
    job.params.should == [1, 2, 3]
  end

  it 'should understand expires_in' do
    job = JobWithExpire.new(1, 2, 3)
    job.expires_in.should == 60*60
    job.expires?.should == true
  end

  context 'job expiration' do
    it 'should expire job by expires_in option' do
      job = TestJob.new
      job.opts['expires_at'] = (Time.now - 10).to_i
      job.expired?.should == true
    end

    it 'should expire job by expires_in option in job class and current_time' do
      job = JobWithExpire.new(1, 2, 3)
      job.opts['created_at'] = (Time.now - job.expires_in - 10).to_i
      job.expired?.should == true
    end

    it 'should not be expired with default params' do
      job = TestJob.new(1, 2, 3)
      job.opts['created_at'] = (Time.now).to_i
      job.expired?.should == false
    end
  end
end