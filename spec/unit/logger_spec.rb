# -*- encoding : utf-8 -*-
require 'spec_helper'

describe RabbitJobs::Logger do
  it '#log should write messages to stdout' do
    mock($stdout).puts "hello"
    RabbitJobs::Logger.log("hello")
  end

  it '#log! should not write messages to stdout in normal mode' do
    RabbitJobs::Logger.verbose = false

    dont_allow(RabbitJobs::Logger).log("hello")
    RabbitJobs::Logger.log!("hello")
  end

  it '#log! should write messages to stdout in verbose mode' do
    RabbitJobs::Logger.verbose = true

    mock(RabbitJobs::Logger).log("hello")
    RabbitJobs::Logger.log!("hello")
  end
end