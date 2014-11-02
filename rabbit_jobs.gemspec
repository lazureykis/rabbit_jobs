$LOAD_PATH.push File.expand_path('../lib', __FILE__)
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'rabbit_jobs/version'

Gem::Specification.new do |spec|
  spec.authors       = ['Pavel Lazureykis']
  spec.email         = ['lazureykis@gmail.com']
  spec.description   = 'Background jobs on RabbitMQ'
  spec.summary       = 'Background jobs on RabbitMQ'
  spec.homepage      = ''
  spec.date          = Time.now.strftime('%Y-%m-%d')

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(/^spec/)
  spec.name          = 'rabbit_jobs'
  spec.require_paths = ['lib']
  spec.version       = RabbitJobs::VERSION
  spec.license       = 'MIT'

  spec.add_dependency 'bunny', '~> 1.6.0'
  spec.add_dependency 'rake'
  spec.add_dependency 'rufus-scheduler', '~> 3.0'
  spec.add_dependency 'activesupport', '~> 4.0'

  spec.add_development_dependency 'bundler'
  # spec.add_development_dependency "rake"
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rr'
  spec.add_development_dependency 'simplecov'
end
