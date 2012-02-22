# require 'resque/tasks'
# will give you the resque tasks

require 'rabbit_jobs'
require 'logger'

namespace :rj do
  def initialize_rj_daemon(daemon)
    daemon.pidfile = ENV['PIDFILE']
    daemon.background = %w(yes true).include? ENV['BACKGROUND']
    RJ.logger = ::Logger.new(ENV['LOGFILE']) if ENV['LOGFILE']
    RJ.logger.level = ENV['VERBOSE'] ? Logger::INFO : Logger::WARN

    worker
  end

  task :setup

  desc "Start a Rabbit Jobs worker"
  task :worker => [ :preload, :setup ] do
    require 'rabbit_jobs'

    queues = (ENV['QUEUES'] || ENV['QUEUE']).to_s.split(',')
    worker = initialize_rj_daemon(RJ::Worker.new(*queues))

    worker.work
  end

  desc "Start a Rabbit Jobs scheduler"
  task :scheduler => [ :preload, :setup ] do
    scheduler = initialize_rj_daemon(RabbitJobs::Scheduler.new)

    scheduler.work
  end

  desc "Start multiple Resque workers. Should only be used in dev mode."
  task :workers do
    threads = []

    ENV['COUNT'].to_i.times do
      threads << Thread.new do
        system "rake resque:worker"
      end
    end

    threads.each { |thread| thread.join }
  end

  # Preload app files if this is Rails
  task :preload => :setup do
    if defined?(Rails) && Rails.respond_to?(:application)
      # Rails 3
      # Rails.application.eager_load!
      Rails.application.require_environment!
    elsif defined?(Rails::Initializer)
      # Rails 2.3
      $rails_rake_task = false
      Rails::Initializer.run :load_application_classes
    end
  end
end