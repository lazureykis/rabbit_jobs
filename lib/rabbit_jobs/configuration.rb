# -*- encoding : utf-8 -*-

module RabbitJobs
  class Configuration
    def self.host
      "localhost"
    end

    def self.queue
      {
        name: "rabbit_jobs_test",
        params: {
          # auto_delete: true
        }
      }
    end
  end
end