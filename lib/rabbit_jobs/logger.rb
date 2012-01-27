module RabbitJobs
  module Logger
    extend self

    def log(string)
      puts string
    end

    def log!(string)
      @@verbose ||= false
      log(string) if @@verbose
    end

    attr_accessor :verbose
    def verbose=(value)
      puts 'logger verbose: ' + value.to_s
      @@verbose = value
    end
  end
end