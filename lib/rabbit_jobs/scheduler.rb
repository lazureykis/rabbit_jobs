# -*- encoding : utf-8 -*-

require 'rufus/scheduler'
require 'thwait'
require 'yaml'

module RabbitJobs
  class Scheduler
    include MainLoop

    attr_accessor :schedule, :process_name

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
          setup_job_schedule(name, config)
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
      queue = config['queue'] || config[:queue] || RabbitJobs.config.routing_keys.first

      RabbitJobs.logger.info "publishing #{config} at #{Time.now}"
      RabbitJobs.publish_to(queue, klass_name, *params)
    rescue
      RabbitJobs.logger.warn "Failed to publish #{klass_name}:\n #{$!}\n params = #{params.inspect}"
      RabbitJobs.logger.warn $!.inspect
    end

    def rufus_scheduler
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
      begin
        return false unless startup

        $0 = self.process_name || "rj_scheduler"

        RabbitJobs.logger.info "Started."

        load_schedule!

        return main_loop(time)
      rescue
        log_daemon_error($!)
      end

      true
    end

    def startup
      # Fix buffering so we can `rake rj:work > resque.log` and
      # get output from the child in there.
      $stdout.sync = true

      @shutdown = false

      Signal.trap('TERM') { shutdown }
      Signal.trap('INT')  { shutdown! }

      true
    end

    def setup_job_schedule(name, config)
      interval_defined = false
      %w(cron every).each do |interval_type|
        if !config[interval_type].nil? && config[interval_type].length > 0
          RabbitJobs.logger.info "queueing #{config['class']} (#{name})"
          rufus_scheduler.send(interval_type, config[interval_type], blocking: true) do
            publish_from_config(config)
          end
          interval_defined = true
        end
      end
      unless interval_defined
        RabbitJobs.logger.warn "no #{interval_types.join(' / ')} found for #{config['class']} (#{name}) - skipping"
      end
    end
  end
end