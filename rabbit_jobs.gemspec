# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'rabbit_jobs/version'

Gem::Specification.new do |gem|
  gem.authors       = ["Pavel Lazureykis"]
  gem.email         = ["lazureykis@gmail.com"]
  gem.description   = %q{Background jobs on RabbitMQ}
  gem.summary       = %q{Background jobs on RabbitMQ}
  gem.homepage      = ""
  gem.date          = Time.now.strftime('%Y-%m-%d')

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "rabbit_jobs"
  gem.require_paths = ["lib"]
  gem.version       = RabbitJobs::VERSION

  gem.add_dependency "bunny", "0.9.0"
  gem.add_dependency "rake"
  gem.add_dependency "rufus-scheduler", "~> 2.0"
  gem.add_dependency "rails", "~> 3.2"
end
