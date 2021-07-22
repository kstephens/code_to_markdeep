# frozen_string_literal: true

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
##$ END HIDDEN

module CodeToMarkdeep
  INITS = [ ]

  ### Main Driver
  class Main

  attr_reader :args, :exitcode
  attr_reader :verbose, :debug, :logger

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
    @debug   = (ENV['CTMD_DEBUG'] || 0).to_i
    @logger  = ::Logger.new($stderr)
    @logger.formatter = Proc.new do | severity, datetime, progname, msg |
      "%-6s %s\n" % [ severity, msg ]
    end
    
    @lines = [ ]
    @state = :INITIALIZE
    @log_line = "~~~INITIALIZE~~~"
    Lang.initialize! self
  end
  
  def main args
    @args = args
    @exitcode = 0
    @rx_cache = {}
    run!
  end

  def run!
    logger.info "started"
    t0 = Time.now
    if debug >= 1
      process! args[0], args[1]
    else
      Timeout.timeout(60) do
        process! args[0], args[1]
      end
    end
  ensure
    t1 = Time.now
    msg = "#{$! && $!.inspect} finished in #{t1 - t0} sec"
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

  def log msg = nil, log_line = nil
    log_line ||= @log_line
    
    if file_name = (log_line.file rescue nil) and @log_file_name != file_name
      @log_file_name = file_name
      logger.debug do
        log_msg "file", file_name
      end
    end

    logger.debug do
      msg = log_msg(msg || yield, log_line)
      if log_line
        msg << '%3s ' % (log_line.lineno rescue '_')
        msg << "|#{log_line.to_s}|"
      else
        msg << '<EOF>'
      end
    end
  end

  def log_msg msg = nil, log_line = nil
    log_line ||= @log_line
    '%-35s' % "#{log_line.lang.name rescue '_'} : #{state} : #{msg} "
  end
end
end

