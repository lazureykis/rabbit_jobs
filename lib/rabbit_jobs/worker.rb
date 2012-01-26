# -*- encoding : utf-8 -*-

module RabbitJobs
  class Worker
    extend Helpers

    # Subscribes to channel and working on jobs
    def run_loop
      @shutdown = false

      # todo: register signals

      host = Configuration.host
      queue_params = Configuration.queue_params
      exchange_name = Configuration.exchange_name
      exchange_params = Configuration.exchange_params
      publish_params = Configuration.publish_params

      channel_exception_handler = Proc.new do |ch, channel_close|
        EM.stop
        raise "channel error: #{channel_close.reply_text}"
      end

      AMQP.start(host: host) do |connection|
        channel  = AMQP::Channel.new(connection)

        channel.prefetch(1)
        channel.on_error(&channel_exception_handler)

        exchange = channel.direct(exchange_name, exchange_params)

        # create queues and subscribe
        queues = []
        Configuration.queues.each do |routing_key|
          queue_name = Configuration.queue_name(routing_key)
          queue = channel.queue(queue_name, queue_params).bind(exchange, :routing_key => routing_key)

          queue.subscribe(ack: true) do |metadata, payload|
            # TODO: handle exceptions, requeue in some minutes, locks
            # run_job(payload)
            puts payload
            metadata.ack
          end

          queues << queue
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

    private

    def run_job message
      begin
        params = JSON.parse(message[:payload])
        klass_name = params.delete_at(0)
        klass = klass_name.constantize
        log "#{Time.zone.now.utc.to_s(:db)} #{klass} #{params == [] ? '' : params.inspect}"
        klass.send(:perform, *params)
      rescue
        log "JOB ERROR at #{Time.zone.now.utc.to_s(:db)}:"
        log $!.inspect
        log $!.backtrace
        log "message: #{message[:payload].inspect}"
        Mailer.send(klass_name, params, $!)
      ensure
        # Publisher.remove_lock(message[:payload])
      end
    end

    def log(message)
      puts(message) unless Rails.env.test?
    end
  end
end
