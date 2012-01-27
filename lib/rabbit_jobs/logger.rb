module RabbitJobs
  module Logger
    extend self

    def log(string)
      puts string
    end

    def log!(string)
      @@verbose ||= false
      log(string) if RabbitJobs::Logger.verbose
    end

    class << self
      attr_accessor :verbose
    end
  end
end