require 'rabbit_jobs'
require 'logger'
require 'rake'

def rails_env
  $my_rails_env ||= defined?(Rails) ? Rails.env : (ENV['RAILS_ENV'] || 'development')
end

def app_root
  $my_rails_root ||= Pathname.new(ENV['RAILS_ROOT'] || Rails.root)
end

def make_dirs
  ["log", "tmp", "tmp/pids"].each do |subdir|
    dir = app_root.join(subdir)
    Dir.mkdir(dir) unless File.directory?(dir)
  end
end

namespace :rj do
  task :environment do
    Rails.application.require_environment!
  end

  desc "Start a Rabbit Jobs worker"
  task :worker => :environment do
    queues = (ENV['QUEUES'] || ENV['QUEUE'] || "").split(',')
    make_dirs
    worker = RJ::Worker.new(*queues)
    worker.consumer = RJ::Consumer.const_get(ENV['CONSUMER'].classify).new if ENV['CONSUMER']
    worker.process_name = "rj_worker #{rails_env} [#{queues.join(',')}]"
    exit(worker.work)
  end

  desc "Start a Rabbit Jobs scheduler"
  task :scheduler do
    make_dirs
    scheduler = RabbitJobs::Scheduler.new
    scheduler.process_name = "rj_scheduler #{rails_env}"
    exit(scheduler.work)
  end
end