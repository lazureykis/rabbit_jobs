require 'simplecov'
SimpleCov.start do
  add_filter 'spec' # ignore spec files
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

  if ENV['CC_BUILD_ARTIFACTS']
    # "-c -f p -f h -o #{ENV['CC_BUILD_ARTIFACTS']}/rspec_report.html"
    config.out = File.open "#{ENV['CC_BUILD_ARTIFACTS']}/rspec_report.html", 'w'
    # config.color_enabled = true
    # config.formatter = :progress
    config.formatter = :html
  end
end
