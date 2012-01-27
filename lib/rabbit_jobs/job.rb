# -*- encoding : utf-8 -*-
require 'json'

module RabbitJobs
  class Job
    include RabbitJobs::Helpers
    include Logger

    attr_accessor :params, :klass

    def initialize(payload)
      begin
        self.params = JSON.parse(payload)
        klass_name = params.delete_at(0)
        self.klass = constantize(klass_name)
      rescue
        log "JOB INIT ERROR at #{Time.now.to_s}:"
        log $!.inspect
        log $!.backtrace
        log "message: #{payload.inspect}"
        # Mailer.send(klass_name, params, $!)
      end
    end

    def perform
      if @child = fork
        srand # Reseeding
        log! "Forked #{@child} at #{Time.now} to process #{klass}.perform(#{ params.map(&:inspect).join(', ') })"
        Process.wait(@child)
        yield if block_given?
      else
        begin
          # log 'before perform'
          klass.perform(*params)
          # log 'after perform'
        rescue
          puts $!.inspect
        end
        exit!
      end
    end
  end
end