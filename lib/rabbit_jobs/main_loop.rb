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
          if defined?(amqp_connection) # in worker only
            amqp_connection.stop
            amqp_channel.work_pool.join
          end
          yield if block_given?
          return true
        end
      end
    end

    def log_daemon_error(error)
      if RabbitJobs.logger
        begin
          RabbitJobs.logger.fatal error
        ensure
          abort(error.message)
        end
      end
    end
  end
end
