# -*- encoding : utf-8 -*-

module RabbitJobs
  class Worker
    include AmqpHelpers

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
      @queues = queues.map { |queue| queue.to_s.strip }
      validate_queues
    end

    def queues
      @queues.map {|queue| queue == "*" ? RabbitJobs.config.routing_keys.sort : queue }.flatten.uniq
    end

    # A worker must be given a queue, otherwise it won't know what to
    # do with itself.
    #
    # You probably never need to call this.
    def validate_queues
      if @queues.nil? || @queues.empty?
        raise NoQueueError.new("Please give each worker at least one queue.")
      end
    end

    # Subscribes to channel and working on jobs
    def work
      puts "pid: #{Process.pid}"
      @shutdown = false

      trap('TERM') { shutdown }
      trap('INT')  { shutdown! }

      amqp_with_exchange do |connection, exchange|
        queues.each do |routing_key|
          queue = make_queue(exchange, routing_key)

          queue.subscribe(ack: true) do |metadata, payload|
            puts "got: #{payload}"
            if payload =~ /SHUTDOWN/
              shutdown
              puts "shutting down"
            else
              job = Job.new(payload)
              job.perform
              # JobRunner.perform(payload)
            end
            # if @child = fork
            #   srand # Reseeding
            #   puts "Forked #{@child} at #{Time.now.to_i} to process #{payload}"
            #   Process.wait(@child)
            # else
            #   puts "Processing #{queue.name} since #{Time.now.to_i}"
            #   exit! unless @cant_fork
            # end
            # metadata.ack
          end
        end

        EM.add_timer(5.5) do
          self.shutdown
        end

        EM.add_periodic_timer(1.0) do
          if @shutdown
            puts "Cancelled default consumer..."
            connection.close { EM.stop }
          end
        end
      end
    end

    def shutdown
      @shutdown = true
    end

    def startup
      # prune_dead_workers

      # Fix buffering so we can `rake rj:work > resque.log` and
      # get output from the child in there.
      $stdout.sync = true
    end

    def shutdown!
      shutdown
      kill_child
    end

    def kill_child
      if @child
        # log! "Killing child at #{@child}"
        if system("ps -o pid,state -p #{@child}")
          Process.kill("KILL", @child) rescue nil
        else
          # log! "Child #{@child} not found, restarting."
          # shutdown
        end
      end
    end
  end
end
