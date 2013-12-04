# -*- encoding : utf-8 -*-

module RabbitJobs
  module Helpers
    def symbolize_keys!(hash)
      hash.inject({}) do |options, (key, value)|
        options[(key.to_sym rescue key) || key] = value
        options
      end
    end


    # Tries to find a constant with the name specified in the argument string:
    #
    # constantize("Module") # => Module
    # constantize("Test::Unit") # => Test::Unit
    #
    # The name is assumed to be the one of a top-level constant, no matter
    # whether it starts with "::" or not. No lexical context is taken into
    # account:
    #
    # C = 'outside'
    # module M
    #   C = 'inside'
    #   C # => 'inside'
    #   constantize("C") # => 'outside', same as ::C
    # end
    #
    # NameError is raised when the constant is unknown.
    def constantize(camel_cased_word)
      camel_cased_word = camel_cased_word.to_s

      if camel_cased_word.include?('-')
        camel_cased_word = classify(camel_cased_word)
      end

      names = camel_cased_word.split('::')
      names.shift if names.empty? || names.first.empty?

      constant = Object
      names.each do |name|
        args = Module.method(:const_get).arity != 1 ? [false] : []

        if constant.const_defined?(name, *args)
          constant = constant.const_get(name)
        else
          constant = constant.const_missing(name)
        end
      end
      constant
    end
  end
end