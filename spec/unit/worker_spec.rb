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

    it '#shutdown! should kill child process' do
      mock(@worker.kill_child)
      mock(@worker.shutdown)

      @worker.shutdown!
    end

    it '#kill_child' do
      job = TestJob.new()
      job.instance_variable_set '@child_pid', 123123
      @worker.instance_variable_set('@job', job)

      mock(Kernel).system("ps -o pid,state -p #{123123}") { true }
      mock(Process).kill("KILL", 123123)

      @worker.kill_child
    end
  end
end