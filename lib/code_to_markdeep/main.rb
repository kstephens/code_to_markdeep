
################################
### code-to-markdeep
### 
### Translates literate programs to markdeep.
### 

##$ BEGIN HIDDEN
require 'code_to_markdeep'
require 'code_to_markdeep/line'
require 'code_to_markdeep/lang'
require 'code_to_markdeep/source_file'
require 'code_to_markdeep/input'
require 'code_to_markdeep/output'
require 'code_to_markdeep/parse'
require 'code_to_markdeep/art'
require 'code_to_markdeep/markdown'
require 'code_to_markdeep/code'
require 'code_to_markdeep/meta'
require 'fileutils'
require 'delegate'
require 'timeout'
require 'logger'
require 'awesome_print'
require 'pry'

begin
  RubyVM::InstructionSequence.compile_option = {
    tailcall_optimization: true,
    # trace_instruction: false
  }
rescue
end
##$ END HIDDEN

module CodeToMarkdeep
  INITS = [ ]

  ### Main Driver
  class Main

  attr_reader :args, :exitcode
  attr_reader :verbose, :logger

  #####################################

  include Input
  include Output
  include Parse
  include Markdown
  include Art
  include Code
  include Meta

  #####################################

  def initialize
    @verbose = (ENV['CTMD_VERBOSE'] || 0).to_i
    @logger  = ::Logger.new($stderr)
  end
  
  def main args
    @args = args
    @exitcode = 0
    @rx_cache = {}
    run!
  end

  def run!
    logger.info "  #{$0} : started"
    t0 = Time.now
    Timeout.timeout(20) do
      process! args[0], args[1]
    end
  ensure
    t1 = Time.now
    msg = "#{$0} : #{$! && $!.inspect} finished in #{t1 - t0} sec"
    if exc = $!
      logger.error msg
      logger.error exc.backtrace.map(&:to_s) * "\n"
      @exitcode = 1
    else
      logger.info  msg
    end
  end

  ##############################

  def process! input_file, output_file
    INITS.each do | sel |
      send(sel)
    end

    # puts Lang[:C].describe

    read_input_file! input_file
    write_output_file! output_file

    create_markdeep_html!
    # create_reveal_html!
    copy_resources!
    process_sources!
    self
  end

  ##############################

  def cache_regex str
    str and
      @rx_cache[str] ||= Regexp.new(str)
  end

  def log msg = nil
    logger.debug "  #{msg} #{state.inspect} |#{line || "~~EOF~~"}|"
  end


end
end

