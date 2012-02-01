# -*- encoding : utf-8 -*-

module RabbitJobs
  class Worker
    include AmqpHelpers
    include Logger

    attr_accessor :pidfile, :background

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
    end

    def queues
      @queues || ['default']
    end

    # Subscribes to channel and working on jobs
    def work(time = 0)
      startup

      processed_count = 0
      amqp_with_exchange do |connection, exchange|
        exchange.channel.prefetch(1)

        check_shutdown = Proc.new {
          if @shutdown
            log "Processed jobs: #{processed_count}"
            log "Stopping worker..."

            connection.close {
              File.delete(self.pidfile) if self.pidfile
              EM.stop { exit! }
            }
          end
        }

        queues.each do |routing_key|
          queue = make_queue(exchange, routing_key)

          log "Worker ##{Process.pid} <= #{exchange.name}##{routing_key}"

          queue.subscribe(ack: true) do |metadata, payload|
            @job = RabbitJobs::Job.parse(payload)
            unless @job.expired?
              @job.run_perform
              metadata.ack
              processed_count += 1
            end
            check_shutdown.call
          end
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
    end

    def shutdown
      @shutdown = true
    end

    def startup
      # prune_dead_workers

      Process.daemon(true) if self.background

      if self.pidfile
        File.open(self.pidfile, 'w') { |f| f << Process.pid }
      end

      # Fix buffering so we can `rake rj:work > resque.log` and
      # get output from the child in there.
      $stdout.sync = true

      @shutdown = false

      Signal.trap('TERM') { shutdown }
      Signal.trap('INT')  { shutdown! }
    end

    def shutdown!
      shutdown
      kill_child
    end

    def kill_child
      if @job && @job.child_pid
        # log! "Killing child at #{@child}"
        if Kernel.system("ps -o pid,state -p #{@job.child_pid}")
          Process.kill("KILL", @job.child_pid) rescue nil
        else
          # log! "Child #{@child} not found, restarting."
          # shutdown
        end
      end
    end
  end
end
