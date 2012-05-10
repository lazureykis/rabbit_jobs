# -*- encoding : utf-8 -*-

module RabbitJobs::Util
  # clean old worker process
  def self.check_pidfile(pidfile)
    if File.exists?(pidfile)
      pid = File.read(pidfile).to_i
      begin
        Process.kill(0, pid)
        RJ.logger.info "Killing old rabbit_jobs process ##{pid}"
        Process.kill("TERM", pid)

        while Process.kill(0, pid)
          sleep(0.5)
        end
      rescue
        File.delete(pidfile) if File.exists?(pidfile)
      end
    end
  end
end