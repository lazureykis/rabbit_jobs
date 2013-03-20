# -*- encoding : utf-8 -*-

module RabbitJobs
  class Worker
    attr_accessor :pidfile, :background, :process_name, :worker_pid

    attr_accessor :_connection, :_channel

    def amqp_connection
      self._connection ||= AmqpHelper.prepare_connection(self._connection)
    end

    def amqp_channel
      self._channel ||= AmqpHelper.create_channel(self._connection)
    end

    def cleanup
      self._connection = self._channel = nil
    end

    def process_message(metadata, payload)
      job = RJ::Job.parse(payload)

      if job.is_a?(Symbol)
        # case @job
        # when :not_found
        # when :parsing_error
        # when :error
        # end
      else
        if job.expired?
          RJ.logger.warn "Job expired: #{job.to_ruby_string}"
          false
        else
          job.run_perform
        end
      end

      true
    end

    def queue_name(routing_key)
      RJ.config.queue_name(routing_key)
    end

    def queue_params(routing_key)
      RJ.config[:queues][routing_key]
    end

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
      @queues = queues.map { |queue| queue.to_s.strip }.flatten.uniq
      if @queues == ['*'] || @queues.empty?
        @queues = RabbitJobs.config.routing_keys
      end
      raise "Cannot initialize worker without queues." if @queues.empty?
    end

    def queues
      @queues || []
    end

    # Subscribes to queue and working on jobs
    def work(time = 0)
      return false unless startup

      $0 = self.process_name || "rj_worker (#{queues.join(', ')})"

      processed_count = 0

      begin
        RJ.run do
          check_shutdown = Proc.new {
            if @shutdown
              RJ.stop
              RJ.logger.info "Processed jobs: #{processed_count}."
              RJ.logger.info "Stopped."

              File.delete(self.pidfile) if self.pidfile && File.exists?(self.pidfile)
            end
          }

          amqp_connection
          amqp_channel.prefetch(1)

          queues.each do |routing_key|
            routing_key = routing_key.to_sym

            amqp_channel.queue(queue_name(routing_key), queue_params(routing_key)) { |queue, declare_ok|
              explicit_ack = !!queue_params(routing_key)[:ack]

              RJ.logger.info "Subscribing to #{queue_name(routing_key)}"
              queue.subscribe(ack: explicit_ack) do |metadata, payload|
                if RJ.run_before_process_message_callbacks
                  begin
                    processed_count += 1 if process_message(metadata, payload)
                  rescue
                    RJ.logger.warn "process_message failed. payload: #{payload.inspect}"
                    RJ.logger.warn $!.inspect
                    $!.backtrace.each {|l| RJ.logger.warn l}
                  end
                  metadata.ack if explicit_ack
                else
                  RJ.logger.warn "before_process_message hook failed, requeuing payload: #{payload.inspect}"
                  metadata.reject(requeue: true) if explicit_ack
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

          RJ.logger.info "Started."
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

      count = RJ._run_after_fork_callbacks

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
