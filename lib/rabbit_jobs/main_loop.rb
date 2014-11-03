module RabbitJobs
  # Main process loop.
  module MainLoop
    def startup
      $stdout.sync = true

      @shutdown = false

      Signal.trap('TERM') { shutdown }
      Signal.trap('INT')  { shutdown! }

      true
    end

    def shutdown
      @shutdown = true
    end

    def shutdown!
      shutdown
    end

    def main_loop
      loop do
        sleep 0.5
        next unless @shutdown

        RabbitJobs.logger.info 'Stopping.'
        if defined?(amqp_connection) # in worker only
          amqp_connection.stop
          consumer_channel.work_pool.join
          amqp_cleanup
        end
        yield if block_given?
        return true
      end
    end

    def log_daemon_error(error)
      return unless RabbitJobs.logger

      RabbitJobs.logger.fatal error
    ensure
      abort(error.message)
    end
  end
end
