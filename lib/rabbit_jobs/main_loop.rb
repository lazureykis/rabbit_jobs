# -*- encoding : utf-8 -*-
module RabbitJobs
  module MainLoop
    def shutdown
      @shutdown = true
    end

    def shutdown!
      shutdown
    end

    def main_loop(time)
      loop do
        sleep 1
        if time > 0
          time -= 1
          if time == 0
            shutdown
          end
        end

        if @shutdown
          RabbitJobs.logger.info "Stopping."
          amqp_connection.stop
          yield if block_given?
          return true
        end
      end
    end

    def log_daemon_error(error)
      if RabbitJobs.logger
        begin
          RabbitJobs.logger.error [error.message, error.backtrace].flatten.join("\n")
        ensure
          abort(error.message)
        end
      end
    end
  end
end