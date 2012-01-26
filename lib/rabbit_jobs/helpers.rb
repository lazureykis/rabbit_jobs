# -*- encoding : utf-8 -*-

module RabbitJobs
  module Helpers
    def symbolize_keys!(hash)
      hash.inject({}) do |options, (key, value)|
        options[(key.to_sym rescue key) || key] = value
        options
      end
    end
  end
end