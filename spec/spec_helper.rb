# -*- encoding : utf-8 -*-
require 'simplecov'
SimpleCov.start
require 'rr'

require 'rabbit_jobs'

RSpec.configure do |config|
  config.mock_with :rr
  # or if that doesn't work due to a version incompatibility
  # config.mock_with RR::Adapters::Rspec
end