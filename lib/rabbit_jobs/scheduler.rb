# -*- encoding : utf-8 -*-

require 'rufus/scheduler'
require 'thwait'
require 'yaml'

module RabbitJobs
  class Scheduler

    attr_accessor :pidfile, :background, :schedule, :process_name

    def load_default_schedule
      if defined?(Rails)
        file = Rails.root.join('config/schedule.yml')
        if file.file?
          @schedule = YAML.load_file(file)
        end
      end
    end

    # Pulls the schedule from Resque.schedule and loads it into the
    # rufus scheduler instance
    def load_schedule!
      @schedule ||= load_default_schedule

      raise "You should setup a schedule or place it in config/schedule.yml" unless schedule

      schedule.each do |name, config|
        # If rails_env is set in the config, enforce ENV['RAILS_ENV'] as
        # required for the jobs to be scheduled.  If rails_env is missing, the
        # job should be scheduled regardless of what ENV['RAILS_ENV'] is set
        # to.
        if config['rails_env'].nil? || rails_env_matches?(config)
          interval_defined = false
          interval_types = %w{cron every}
          interval_types.each do |interval_type|
            if !config[interval_type].nil? && config[interval_type].length > 0
              RJ.logger.info "queueing #{config['class']} (#{name})"
              rufus_scheduler.send(interval_type, config[interval_type]) do
                publish_from_config(config)
              end
              interval_defined = true
              break
            end
          end
          unless interval_defined
            RJ.logger.warn "no #{interval_types.join(' / ')} found for #{config['class']} (#{name}) - skipping"
          end
        end
      end
    end

    # Returns true if the given schedule config hash matches the current ENV['RAILS_ENV']
    def rails_env_matches?(config)
      config['rails_env'] && ENV['RAILS_ENV'] && config['rails_env'].gsub(/\s/,'').split(',').include?(ENV['RAILS_ENV'])
    end

    # Publish a job based on a config hash
    def publish_from_config(config)
      args = config['args'] || config[:args] || []
      klass_name = config['class'] || config[:class]
      params = args.is_a?(Hash) ? [args] : Array(args)
      queue = config['queue'] || config[:queue] || RJ.config.routing_keys.first

      RJ.logger.info "publishing #{config} at #{Time.now}"
      RJ.publish_to(queue, klass_name, *params)
    rescue
      RJ.logger.warn "Failed to publish #{klass_name}:\n #{$!}\n params = #{params.inspect}"
      RJ.logger.warn $!.inspect
    end

    def rufus_scheduler
      raise "Cannot start without eventmachine running." unless EM.reactor_running?
      @rufus_scheduler ||= Rufus::Scheduler.start_new
    end

    # Stops old rufus scheduler and creates a new one.  Returns the new
    # rufus scheduler
    def clear_schedule!
      rufus_scheduler.stop
      @rufus_scheduler = nil
      rufus_scheduler
    end

    # Subscribes to channel and working on jobs
    def work(time = 0)
      return false unless startup

      $0 = self.process_name || "rj_scheduler"

      processed_count = 0
      RJ.run do
        AmqpHelper.prepare_channel

        load_schedule!

        check_shutdown = Proc.new {
          if @shutdown
            RJ.stop {
              File.delete(self.pidfile) if self.pidfile
              exit!
            }
          end
        }

        if time > 0
          # for debugging
          EM.add_timer(time) do
            self.shutdown
          end
        end

        RJ.logger.info "Scheduler started."

        EM.add_periodic_timer(1) do
          check_shutdown.call
        end
      end

      true
    end

    def shutdown
      RJ.logger.warn "Stopping scheduler..."
      @shutdown = true
    end

    def startup
      # prune_dead_workers
      RabbitJobs::Util.check_pidfile(self.pidfile) if self.pidfile

      if self.background
        child_pid = fork
        if child_pid
          return false
        else
          # daemonize child process
          Process.daemon(true)
        end
      end

      if self.pidfile
        File.open(self.pidfile, 'w') { |f| f << Process.pid }
      end

      # Fix buffering so we can `rake rj:work > resque.log` and
      # get output from the child in there.
      $stdout.sync = true

      @shutdown = false

      Signal.trap('TERM') { shutdown }
      Signal.trap('INT')  { shutdown! }

      true
    end

    def shutdown!
      shutdown
    end
  end
end