# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Job do
  it 'should parse class and params' do
    job = RabbitJobs::Job.parse((['TestJob',1,2,3]).to_json)
    job.params.should == [1, 2, 3]
  end

  it 'should understand expires_in' do
    job = JobWithExpire.new(1, 2, 3)
    job.expires_in.should == 60*60
    job.expires?.should == true
  end
end