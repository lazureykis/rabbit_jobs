# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Job do
  it 'should parse klass and params' do
    # job = RabbitJobs::Job.parse([TestJob, 1, 2, 3].to_json)
    job = TestJob.new(1, 2, 3)
    job.klass.should == TestJob
    job.params.should == [1, 2, 3]
  end

  it 'should accept lock_with_params options' do
    job = TestJobLockedWithParams.new(1, 2, 3)
    job.locked.should == :with_params
    job.locked?.should == true
  end
end