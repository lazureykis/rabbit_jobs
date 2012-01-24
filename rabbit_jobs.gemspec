# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rabbit_jobs/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Pavel Lazureykis"]
  gem.email         = ["lazureykis@gmail.com"]
  gem.description   = %q{Background jobs on RabbitMQ}
  gem.summary       = %q{Background jobs on RabbitMQ}
  gem.homepage      = ""

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "rabbit_jobs"
  gem.require_paths = ["lib"]
  gem.version       = RabbitJobs::VERSION

  gem.add_development_dependency "rspec", "~> 2.8"

  gem.add_dependency "amqp", "~> 0.9"
end
