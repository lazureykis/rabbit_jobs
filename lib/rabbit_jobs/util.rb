# -*- encoding : utf-8 -*-

module RabbitJobs
  class Util
    class << self

      # clean old worker process
      def check_pidfile(pidfile)
        if File.exists?(pidfile)
          pid = File.read(pidfile).to_i
          begin
            Process.kill(0, pid)
            RJ.logger.info "Killing stale rj_worker[##{pid}]"
            Process.kill("TERM", pid)

            while Process.kill(0, pid)
              sleep(0.5)
            end
          rescue
            File.delete(pidfile) if File.exists?(pidfile)
          end
        end
      end

      def cleanup_backtrace(trace_lines)
        if defined?(Rails) && Rails.respond_to?(:root)
          rails_root_path = Rails.root.to_s
          trace_lines.dup.keep_if { |l| l[rails_root_path] }
        else
          trace_lines
        end
      end

    end
  end
end