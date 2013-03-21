# -*- encoding : utf-8 -*-

module RabbitJobs
  class Util
    class << self

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