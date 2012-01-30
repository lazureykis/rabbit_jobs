# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Job do
  class MyTestJob < RabbitJobs::Job
    def self.perform(one, two, three)
    end
  end

  it 'should perform job' do
    job = RabbitJobs::Job.new([MyTestJob, 1, 2, 3].to_json)
    job.klass.should == MyTestJob
    job.params.should == [1, 2, 3]
    job.perform
  end
end