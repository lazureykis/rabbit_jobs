# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Job do
  it 'should parse klass and params' do
    job = TestJob.new(1, 2, 3)
    job.klass.should == TestJob
    job.params.should == [1, 2, 3]
  end
end