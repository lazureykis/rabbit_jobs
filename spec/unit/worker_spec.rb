# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Worker do
  describe 'methods' do
    before :each do
      @worker = RabbitJobs::Worker.new
    end

    it '#initialize with default options' do
      @worker.queues.should == ['default']
    end

    it '#startup should set @shutdown to false' do
      @worker.instance_variable_get('@shutdown').should_not == true

      mock(Signal).trap('TERM')
      mock(Signal).trap('INT')

      @worker.startup

      @worker.instance_variable_get('@shutdown').should_not == true
    end

    it '#startup should write process id to file' do
      mock(Signal).trap('TERM')
      mock(Signal).trap('INT')

      filename = 'test_worker.pid'
      mock(File).open(filename, 'w') {}
      @worker.pidfile = filename
      @worker.startup
      @worker.pidfile.should == filename
    end

    it '#shutdown should set @shutdown to true' do
      @worker.instance_variable_get('@shutdown').should_not == true
      @worker.shutdown
      @worker.instance_variable_get('@shutdown').should == true
    end
  end
end