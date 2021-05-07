
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
  RX_var_ref    = /\{\{(\w+)\}\}/

  ### Main Driver
  class Main
  #### String with source line metadata

  attr_reader :line, :lines, :out, :vars, :verbose

  attr_reader :lineno
  attr_reader :vars, :var, :dec_var, :source_files

  attr_reader :args, :exitcode
  attr_reader :input_file, :input_dir, :output_file, :output_dir

  def logger
    @logger ||= ::Logger.new($stderr)
  end

  def log msg = nil
    logger.debug "  #{msg} #{state.inspect} |#{line || "~~EOF~~"}|"
  end

  #####################################

  include Input
  include Output
  include Parse
  include Markdown
  include Art
  include Code
  include Meta

  ##############################

  def initialize
    @source_files = { }
  end
  
  def main args
    @args = args
    @exitcode = 0
    run!
  end

  def run!
    logger.info "  #{$0} : started"
    t0 = Time.now
    # Timeout.timeout(20) do
    process!
    #end
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

  def process!
    @input_file  = args[0]
    @output_file = args[1]
    @verbose = (ENV['CTMD_VERBOSE'] || 0).to_i
    @lineno = 0
    @lines = [ ]
    @lines_taken = 0
    @vars       = { }
    @vars_stack = Hash.new{|h,k| h[k] = [ ]}
    @lang_state = { }
    @macros     = { }
    @macro_stack = [ ]
    
    @input_file  = args[0]
    @input_dir  = File.dirname(File.expand_path(@input_file))
    @output_file = args[1]
    @output_dir = File.dirname(File.expand_path(@output_file))
    @html_head = [ ]
    @html_foot = [ ]

    lang = Lang.from_file(@input_file)
    input_line = "<<#{@input_file}>>".freeze
    input_line = Line.new(input_line, original: input_line, lang: lang)
    insert_file(@input_file, input_line)

    logger.info "writing #{@output_file}"
    File.open(@output_file, "w") do | out |
      @out = out
      parse!
    end
    logger.info "writing #{@output_file} : DONE"

    create_markdeep_html!
    # create_reveal_html!
    copy_resources!
    process_sources!
    self
  end
  
  def process_sources!
    logger.info " Source files: #{source_files.size}:"
    source_files.each do | name, sf |
      logger.info "  #{sf} | #{sf.included_by.info}"
    end
    self
  end

end
end

