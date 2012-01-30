# require 'resque/tasks'
# will give you the resque tasks

namespace :rj do
  task :setup

  desc "Start a Rabbit Jobs worker"
  task :work => [ :preload, :setup ] do
    require 'rabbit_jobs'

    queues = (ENV['QUEUES'] || ENV['QUEUE']).to_s.split(',')

    begin
      worker = RabbitJobs::Worker.new(*queues)
      worker.pidfile = ENV['PIDFILE']
      worker.background = %w(yes true).include? ENV['BACKGROUND']
      RabbitJobs::Logger.verbose = true if ENV['VERBOSE']
      # worker.very_verbose = ENV['VVERBOSE']
    end

    # worker.log "Starting worker #{worker.pid}"
    # worker.verbose = true
    worker.work 10
    # worker.work(ENV['INTERVAL'] || 5) # interval, will block
  end

  desc "Start multiple Resque workers. Should only be used in dev mode."
  task :workers do
    threads = []

    ENV['COUNT'].to_i.times do
      threads << Thread.new do
        system "rake resque:work"
      end
    end

    threads.each { |thread| thread.join }
  end

  # Preload app files if this is Rails
  task :preload => :setup do
    if defined?(Rails) && Rails.respond_to?(:application)
      # Rails 3
      Rails.application.eager_load!
    elsif defined?(Rails::Initializer)
      # Rails 2.3
      $rails_rake_task = false
      Rails::Initializer.run :load_application_classes
    end
  end
end