require 'code_to_markdeep'
require 'delegate'

module CodeToMarkdeep
  class Line < Delegator
    attr_reader :to_str
    def __getobj__; @to_str; end

    attr_accessor :original, :file, :lineno, :lang, :source_file, :vars

    def initialize x, opts = nil
      raise unless x
      opts ||= Hash_empty
      o = opts[:original]
      case x
      when Line
        @to_str = x.to_str
        o ||= x
      when String
        @to_str = x.dup.freeze
      end
      @original = o
      opts = _to_h(x).merge(_to_h(o)).merge(opts)
      # ap(Line: {x: x, opts: opts})
      @file, @lineno, @lang, @source_file, @vars =
        opts.values_at(:file, :lineno, :lang, :source_file, :vars)
      # ap(Line: self, caller: caller) unless @lang
      raise unless @lang
    end

    def inspect
      h = to_h
      h[:source_file] = h[:source_file] && h[:source_file].to_s
      "Line[#{h.ai}]"
    end

    def _to_h x
      case x
      when Line
        x.to_h
      else
        Hash_empty
      end
    end
    
    def to_h
      {
        to_str: @to_str,
        original: @original,
        file: @file,
        lineno: @lineno,
        lang: @lang,
        source_file: @source_file,
        vars: @vars,
      }
    end
    
    Hash_empty = {}.freeze

    def info
      "#{file}:#{lineno} #{lang.name} |#{self}|"
    end
  end  
end
