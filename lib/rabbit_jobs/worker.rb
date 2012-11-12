# -*- encoding : utf-8 -*-

module RabbitJobs
  class Worker
    attr_accessor :pidfile, :background, :process_name, :worker_pid

    # Workers should be initialized with an array of string queue
    # names. The order is important: a Worker will check the first
    # queue given for a job. If none is found, it will check the
    # second queue name given. If a job is found, it will be
    # processed. Upon completion, the Worker will again check the
    # first queue given, and so forth. In this way the queue list
    # passed to a Worker on startup defines the priorities of queues.
    #
    # If passed a single "*", this Worker will operate on all queues
    # in alphabetical order. Queues can be dynamically added or
    # removed without needing to restart workers using this method.
    def initialize(*queues)
      RJ.config.init_default_queue
      @queues = queues.map { |queue| queue.to_s.strip }.flatten.uniq
      if @queues == ['*'] || @queues.empty?
        @queues = RabbitJobs.config.routing_keys
      end
    end

    def queues
      @queues || ['default']
    end

    # Subscribes to queue and working on jobs
    def work(time = 0)
      return false unless startup

      $0 = self.process_name || "rj_worker (#{queues.join(',')})"

      processed_count = 0

      begin
        RJ.run do
          check_shutdown = Proc.new {
            if @shutdown
              RJ.stop {
                RJ.logger.info "Processed jobs: #{processed_count}"
                RJ.logger.info "Stopping worker ##{Process.pid}..."
                File.delete(self.pidfile) if self.pidfile && File.exists?(self.pidfile)
                RJ.logger.info "##{Process.pid} stopped."
                RJ.logger.close
                # exit!
              }
            end
          }

          AmqpHelper.prepare_channel

          queues.each do |routing_key|
            AMQP.channel.prefetch(1)
            AMQP.channel.queue(RJ.config.queue_name(routing_key), RJ.config[:queues][routing_key]) { |queue, declare_ok|
              unless declare_ok == 0
                RJ.logger.error "Cannot define queue #{routing_key}."
                next
              end

              RJ.logger.info "Worker ##{Process.pid} <= #{RJ.config.queue_name(routing_key)}"

              explicit_ack = !!RJ.config[:queues][routing_key][:ack]

              queue.subscribe(ack: explicit_ack) do |metadata, payload|
                @job = RJ::Job.parse(payload)

                if @job.is_a?(Symbol)
                  # case @job
                  # when :not_found
                  # when :parsing_error
                  # when :error
                  # end
                  metadata.ack if explicit_ack
                else
                  if @job.expired?
                    RJ.logger.info "Job expired: #{@job.inspect}"
                  else
                    @job.run_perform
                    processed_count += 1
                  end

                  metadata.ack if explicit_ack
                end

                check_shutdown.call
              end
            }
          end

          if time > 0
            # for debugging
            EM.add_timer(time) do
              self.shutdown
            end
          end

          EM.add_periodic_timer(1) do
            check_shutdown.call
          end
        end
      rescue
        error = $!
        if RJ.logger
          begin
            RJ.logger.error [error.message, error.backtrace].flatten.join("\n")
          ensure
            abort(error.message)
          end
        end
      end

      true
    end

    def shutdown
      @shutdown = true
    end

    def startup
      # prune_dead_workers
      RabbitJobs::Util.check_pidfile(self.pidfile) if self.pidfile

      if self.background
        return false if self.worker_pid = fork

        # daemonize child process
        Process.daemon(true)
      end

      self.worker_pid ||= Process.pid

      if self.pidfile
        File.open(self.pidfile, 'w') { |f| f << Process.pid }
      end

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
