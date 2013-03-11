# -*- encoding : utf-8 -*-
require 'simplecov'
SimpleCov.start do
  add_filter "spec" # ignore spec files
end

require 'rr'
require 'timecop'

require 'rabbit_jobs'
require 'fixtures/jobs'

RSpec.configure do |config|
  config.mock_with :rr
  # or if that doesn't work due to a version incompatibility
  # config.mock_with RR::Adapters::Rspec

  config.before(:each) do
    # clear config options
    RabbitJobs.class_variable_set '@@configuration', nil
  end
end