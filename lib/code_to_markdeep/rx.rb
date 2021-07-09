require 'code_to_markdeep'

module CodeToMarkdeep
  module Rx
    class << self
      attr_accessor :log_fn
    end
    
    def self.[] rx
      case rx
      when nil
        rx
      when log_fn
        raise unless Regexp === rx
        WithLogging.new(rx)
      else
        rx
      end
    end
 
    def self.log msg, *args, &blk
      log_fn.call("Rx: #{msg}", *args, &blk)
    end

    class WithLogging
      def initialize rx
        @rx = rx
      end
      
      def self.wrap *meths
        meths.each do | meth |
          eval <<"RUBY"
def #{meth} *_args, &_blk
  _result = @rx.send(#{meth.inspect}, *_args, &_blk)
  Rx.log "#{meth} : \#{@rx.inspect} : \#{_args.map(&:to_s) * ', '} : \#{_result.inspect}"
  _result
end
RUBY
        end
      end
      wrap :===, :=~, :match, :match?
      
      def method_missing sel, *args, &blk
        @rx.send(sel, *args, blk)
      end
    end
  end
end

