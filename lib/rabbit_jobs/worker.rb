# -*- encoding : utf-8 -*-

module RabbitJobs
  class Worker
    include RJ::MainLoop

    attr_accessor :process_name
    attr_reader :consumer

    def consumer=(value)
      raise ArgumentError.new("value=#{value.inspect}") unless value.respond_to?(:process_message)
      @consumer = value
    end

    def amqp_connection
      Thread.current[:rj_worker_connection] ||= AmqpHelper.prepare_connection
    end

    def self.cleanup
      conn = Thread.current[:rj_worker_connection]
      conn.close if conn && conn.status != :not_connected
      Thread.current[:rj_worker_connection] = nil
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
    def work(time = -1)
      return false unless startup
      @consumer ||= RJ::Consumer::JobConsumer.new

      $0 = self.process_name || "rj_worker (#{queues.join(', ')})"

      processed_count = 0

      begin
        # amqp_channel.prefetch(1)

        amqp_channel = amqp_connection.create_channel

        queue_objects = []
        queues.each do |routing_key|
          RJ.logger.info "Subscribing to #{queue_name(routing_key)}"

          routing_key = routing_key.to_sym
          queue = amqp_channel.queue(queue_name(routing_key), queue_params(routing_key))
          queue_objects << queue
          explicit_ack = !!queue_params(routing_key)[:ack]

          queue.subscribe(ack: explicit_ack) do |delivery_info, properties, payload|
            if RJ.run_before_process_message_callbacks
              begin
                @consumer.process_message(delivery_info, properties, payload)
                processed_count += 1
              rescue
                RJ.logger.warn "process_message failed. payload: #{payload.inspect}"
                RJ.logger.warn $!.inspect
                $!.backtrace.each {|l| RJ.logger.warn l}
              end
              amqp_channel.ack(delivery_info.delivery_tag, false) if explicit_ack
            else
              RJ.logger.warn "before_process_message hook failed, requeuing payload: #{payload.inspect}"
              amqp_channel.nack(delivery_info.delivery_tag, true) if explicit_ack
            end

            if @shutdown
              queue_objects.each {|q| q.unsubscribe}
              RJ.logger.info "Processed jobs: #{processed_count}."
            end
          end
        end

        RJ.logger.info "Started."

        return main_loop(time)
      rescue
        log_daemon_error($!)
      end

      true
    end

    def startup
      count = RJ._run_after_fork_callbacks

      $stdout.sync = true

      @shutdown = false

      Signal.trap('TERM') { shutdown }
      Signal.trap('INT')  { shutdown! }

      true
    end
  end
end
