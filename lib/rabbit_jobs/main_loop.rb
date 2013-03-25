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
      while true
        sleep 1
        if time > 0
          time -= 1
          if time == 0
            shutdown
          end
        end

        if @shutdown
          RJ.logger.info "Stopping."

          return true
        end
      end
    end

    def log_daemon_error(error)
      if RJ.logger
        begin
          RJ.logger.error [error.message, error.backtrace].flatten.join("\n")
        ensure
          abort(error.message)
        end
      end
    end
  end
end