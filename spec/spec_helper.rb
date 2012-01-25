# -*- encoding : utf-8 -*-
require 'simplecov'

SimpleCov.start 'rails' do
  add_filter "vendor/ruby" # ignore gems
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"
end

require 'rabbit_jobs'