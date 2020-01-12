### **Bootstrapping a Programming Language**

################################
### code-to-markdeep
### 
### Translates literate programs to markdeep.
### 

##$ BEGIN HIDDEN
require 'code_to_markdeep'
require 'fileutils'
require 'timeout'
require 'logger'
require 'awesome_print'
#require 'pry'

if false
  RubyVM::InstructionSequence.compile_option = {
    tailcall_optimization: true,
    trace_instruction: false
  }
end
##$ END HIDDEN

module CodeToMarkdeep
  ### Main Driver
  class Main
  #### String with source line metadata
  module Line
    attr_accessor :file, :lineno, :lang, :vars
    def self.create line, file = nil, lineno = nil, lang = nil
      line.extend(self) unless line.respond_to?(:file)
      line.file    = file.freeze  if file
      line.lineno  = lineno       if lineno
      line.lang    = lang         if lang
      line
    end
    def info
      "#{file}:#{lineno} |#{self}|"
    end
    def assign_to x
      x.extend(Line)
      x.file = self.file
      x.lineno = self.lineno
      x.lang = self.lang
      x.vars = self.vars
      x
    end
  end

  #### A description of a programming language
  class Lang
    LANG = { }
    def self.from_file file
      LANG.values.find {|l| l.file_name_rx =~ file } || LANG[:C]
    end
    attr_reader :name
    def initialize opts
      @opts = opts
      @opts.each do | k, v |
        instance_variable_set(:"@#{k}", v)
      end
      @name or raise
      C_attrs.each do | k, v |
        next if @opts[k]
        v = convert_rx(v, k) if Regexp === v
        instance_variable_set(:"@#{k}", v)
      end
      LANG[@name] ||= self
    end
 
    def convert_rx rx, k
      return rx if name == :C
      case
      when f = convert_rx_f
        result = f.call(rx, k)
        result = Regexp.new(result) if String === result
        # ap(convert_rx_f: { rx: rx, result: result }) if result
        result = convert_rx_default(rx, k) if result == nil
      else
        result = convert_rx_default(rx, k)
      end
      # ap(convert_rx: { lang: name, k: k, rx: rx, result: result}) if name == :Scheme
      result
    end
    def convert_rx_default rx, k
      s = comment_line[0]
      s = rx.to_s.gsub(%r{\\/}, s)
      Regexp.new(s)
    end

    C_attrs = {
      name:           :C,
      file_name_rx:   /\.[ch]$/,
      comment_begin:  "/*",
      comment_end:    "*/",
      comment_line:   "//",
      text:           "/// ",
      md_begin:       "/*/",
      convert_rx_f: nil,

      emacs_rx: %r{-\*- .* -\*-},
      blank_rx: /^\s*$/,
      html_rx:  %r{^<},
      top_level_brace_rx: /^[}{]\s*$/,
      var_ref_rx:    /\{\{(\w+)\}\}/,
      code_fence_rx: %r{^~~~~*},
      art_rx:        %r{^\*{6,}},

      begin_rx:     %r{//\$\s*BEGIN\s+(\w+)(?:\s+(\S*))?},
      end_rx:       %r{//\$\s*END\s+(\w+)},
      hidden_rx:    %r{//\$\s*HIDDEN},

      head_rx:      %r{^////////+\s*$},
      text_rx:      %r{^//(/+) (.*)},
      macro_rx:     %r{^//\#(\w+)\s*(.*)},
      meta_rx:      %r{^//\!(\w+)\s*(.*)},
      code_line_rx: %r{^//; (.*)},
      md_begin_rx:  %r{^\s*/\*/},
      md_end_rx:    %r{^\s*/\*/},
      comment_line_rx: %r{^\s*//},
    }
    attr_reader *C_attrs.keys
    alias :md_end_rx :md_begin_rx
    alias :md_end    :md_begin

    new(name: :C)
    new(name: :Markdown,
        file_name_rx:   /(\.md$)/,
        )
    new(name: :Ruby,
        file_name_rx:   /(Rakefile|Gemfile|Guardfile|\.rb$)/,
        comment_begin:  "#",
        comment_end:    "#",
        comment_line:   "#",
        text:           "### ",
        md_begin:       "#*# ",
        md_begin_rx:     %r{^\s*#\*#},
        convert_rx_f: lambda do | rx, k |
          # ap(rx: rx, rx_to_s: rx.to_s, rx_inspect: rx.inspect)
          case rx.inspect.gsub(%r{\A/|/\Z}, '')
          when %r{(.*)(\^\\/\\/)(.*)}
            $1 + "^\\s*###" + $3.gsub(%r{/}, ';')
          when %r{(.*)(\\/\\/\\\$)(.*)}
            $1 + "###\\$" + $3.gsub(%r{/}, ';')
          else
            nil
          end
        end
       )
    new(name: :Scheme,
        file_name_rx:   /\.(s(cm)?|rkt)$/,
        comment_begin:  "#|",
        comment_end:    "|#",
        comment_line:   ";;",
        text:           ";;; ",
        md_begin:       "#|>",
        md_begin_rx:     %r{^\s*\#\|\>},
        md_end:         "<|#",
        md_end_rx:      %r{^\s*\<\|\#},
        text_rx:        %r{^;;(;+) (.*)},
        convert_rx_f: lambda do | rx, k |
          # ap(rx: rx, rx_to_s: rx.to_s, rx_inspect: rx.inspect)
          case rx.inspect.gsub(%r{\A/|/\Z}, '')
          when %r{(.*)(\^\\/\\/)(.*)}
            $1 + "^;;" + $3.gsub(%r{/}, ';')
          when %r{(.*)(\\/\\/\\\$)(.*)}
            $1 + ";;\\$" + $3.gsub(%r{/}, ';')
          else
            nil
          end
        end
       )
  end

  attr_reader :state, :line, :lines, :out, :vars, :verbose
  attr_reader :lineno
  attr_reader :vars, :var, :dec_var

  RX_var_ref    = /\{\{(\w+)\}\}/

  def insert_file file
    lines = [ ]
    @lineno = 0
    lang = Lang.from_file(file)
    # lines << Line.create("//$ BEGIN LANG #{lang.name}", file, 0, lang)
    File.open(file) do | inp |
      until inp.eof?
        @lineno += 1
        line = Line.create(inp.readline.chomp, file, lineno, lang)
        lines.push(line)
      end
    end
    # lines << Line.create("//$ END LANG", file, 0, @lineno + 1)
    insert_lines lines
  end

  def insert_lines lines
    @lines = lines + @lines
  end
  
  def insert_line line, lang
    @lines.unshift Line.create(line, nil, nil, lang)
  end

  def logger
    @logger ||= ::Logger.new($stderr)
  end

  def log msg = nil
    logger.debug "  #{msg} #{state.inspect} |#{line || "~~EOF~~"}|"
  end

  def take val = nil
    line = peek
    @peek = nil
    log :take if verbose >= 3
    @lines_taken += 1 if line
    val || line
  end

  def peek
    unless @peek
      log :peek if verbose >= 4
      @peek = _peek
    end
    @line = @peek
  end

  def _peek
    while true
      line = __take
      log :_peek if verbose >= 5

      # HACK:
      case line || ''
      when %r{^#if\s+0}
        line = Line.create("//$ BEGIN HIDDEN", line.file, line.lineno, line.lang)
      when %r{^#endif\s*(//\s*0|/\*\s*0\s*\*/)}
        line = Line.create("//$ END HIDDEN"  , line.file, line.lineno, line.lang)
      end

      var = nil
      capture_macro = true
      case
      when ! line
        unless @eof
          logger.info "  #{$0} : peek: EOF after #{@lines_taken} lines"
          @eof = true
        end
        return nil
      when line =~ line.lang.emacs_rx
      when line.lang.name == :Markdown
        if @macro
          @macro << line
        else
          return line
        end
      when line =~ line.lang.begin_rx
        var = $1.to_sym
        val  = $2
        @vars_stack[var].push(@vars[var])
        # logger.info "  BEGIN #{var.inspect} #{val.inspect}"
        case val
        when nil, ""
          val = (@vars[var] || 0) + 1
        end
        case var
        when :MACRO
          macro_name = val
          @macro_stack.push @macro
          @macro = @macros[macro_name] = [ ]
          logger.info "  MACRO #{macro_name} ..."
        end
        @vars = @vars.dup
        @vars[var] = val
        # ap(var: var, val: val, line: line.info) if var == :LINENO
      when line =~ line.lang.end_rx
        var = $1.to_sym
        @vars = @vars.dup
        val = @vars[var] = @vars_stack[var].pop
        case var
        when :MACRO
          logger.info "  MACRO #{macro_name} : #{@macro.size} lines"
          @macro = @macro_stack.pop
        end
        # ap(var: var, val: val, line: line.info) if var == :LINENO
      when line =~ line.lang.hidden_rx
      when (@vars[:HTML_HEAD] || 0) > 0
        @html_head << line
      when (@vars[:HTML_FOOT] || 0) > 0
        @html_foot << line
      when (@vars[:HIDDEN] || 0) > 0
      else
        $stderr.write '.' if verbose >= 1
        line.vars = @vars
        if @macro
          logger.info "  captured macro #{macro_name}: #{line}"
          @macro << line
        else
          return line
        end
      end
    end
  end

  def __take
    @lines.shift
  end

  def __peek
    @lines.first
  end

  def fmt_code_line line
    lang = line.lang
    lstate = lang_state(lang)
    show_lineno = false
    lstate[:code_lineno] ||= 0
    @lineno_fmt ||= "Li%4snE"
    @lineno_spc ||= (@lineno_fmt % '').gsub(/\s/, '_')

    case line
    when lang.blank_rx, lang.top_level_brace_rx, lang.comment_line_rx
    else
      @code_count ||= 0
      @code_count  += 1
      if (line.vars[:LINENO] || 1).to_i > 0
        show_lineno = true
        lstate[:code_lineno] += 1
      end
    end

    lstate[:code_line_count] = lstate[:code_lineno]

    if show_lineno
      line = line.gsub("\n", "\n" + @lineno_spc)
      lineno = (@lineno_fmt % [ lstate[:code_lineno].to_i.to_s ]).gsub(/\s/, '_') # Make it a "__12" string
    else
      lineno =  @lineno_spc
    end
    "%s %s" % [ lineno, line ]
  end

  def fmt_code line, opts = nil
    opts ||= Empty_Hash
    case line
    when /ox_declare[^)]+;/ # FIXME!!!!
      l = line
      line = line.
        sub(/,([^,;]+);/){|m| ",\n  #{$1};"}.
        gsub(/;/, ";\n  ").
        sub(/\n[^;)\n]*\n\s*\Z/, "\n").
        sub(/;[\n\s]+\)/, ';)').
        sub(/[\n\s]+\Z/, '').
        sub(/;[\n\s]+\/\//, '; //')
      line.chomp
      l.assign_to(line)
      # logger.debug "   #{state} |#{line}|"
    end
    line = fmt_code_line(line) if opts[:lineno]
    line
  end

  CODE_FENCE = "~" * 60
  def code_fence line = nil
    case line
    when nil
      CODE_FENCE + "\n"
    when /^\s*[(]/
      CODE_FENCE + " Scheme"
    else
      CODE_FENCE + " #{line.lang.name}"
    end
  end

  def emit_code_lines lines, opts = nil
    opts ||= Empty_Hash
    while x = lines[0] and x =~ x.lang.blank_rx
      lines.shift
    end
    while x = lines[-1] and x =~ x.lang.blank_rx
      lines.pop
    end
    unless lines.empty?
      @code_count = nil
      formatted_lines = lines.map do | l |
        fmt_code(l, opts)
      end
      @code_count ||= formatted_lines.size
      if opts[:line_count]
        out.puts %Q{<span class="ctmd-line-count">#{@code_count} line#{@code_count == 1 ? '' : 's'}</span>}
      end
      out.puts code_fence(lines.first)
      formatted_lines.each do | l |
        out.puts(l)
      end
      out.puts code_fence
    end
  end
  Empty_Hash = { }.freeze

  def emit_text str, line = str
    str = str.gsub(RX_var_ref) do | m |
      # logger.debug "str = #{str.inspect} $1=#{$1.inspect}"
      @vars[$1.to_sym] || lang_state(line.lang)[$1.to_sym]
    end
    out.puts str
  end

  ###############################################################

  def state new_state = nil
    @state = new_state if new_state
    @state
  end

  def parse!
    state :start
    while peek
      log :parse! if verbose >= 2
      # binding.pry
      send(state)
    end
  end

  def start
    lang = line.lang
    if lang.name == :Markdown
      out.puts line
      take
      return
    end
    case line
    when lang.blank_rx
      out.puts ""
      take
    when lang.html_rx
      out.puts line
      take
    when lang.md_begin_rx
      take
      state :md
    when lang.head_rx
      take
      state :head
    when lang.text_rx
      out.puts ""
      state :text
    when lang.macro_rx
      state :macro
    when lang.meta_rx
      state :meta
    when lang.code_line_rx
      state :code_line
    else
      state :code
    end
  end

  def text
    case line
    when line.lang.text_rx
      emit_text take($2), line
    else
      state :start
    end
  end

  def head
    case line
    when line.lang.text_rx
      level = $1.size
      emit_text "", line
      emit_text("#" * level + " " + $2, line)
    else
      logger.error "UNEXPECTED: #{state.inspect} |#{line}|"
      # binding.pry
    end
    take
    state :start
  end

  def md
    while line = peek
      lang = line.lang
      case peek
      when lang.art_rx
        take
        return state :art
      when lang.md_end_rx
        take
        break
      when lang.code_fence_rx
        take
        md_code_fence
      else
        take
        emit_text line
      end
    end
    state :start
  end

  def art
    @art_lines ||= [ ]
    case line = peek
    when line.lang.art_rx
      take
      # Prepend '* ' to each line, if missing.
      @art_lines.map! do | line |
        line =~ /^\* / ? line : '* ' + line
      end
      # Calc with of fence
      width = @art_lines.map(&:size).max + 2
      art_border = '*' * width

      out.puts art_border
      @art_lines.each do | line |
        # Expand line to fence width
        line << ' ' while line.size < width
        line[width - 1] = '*'
        out.puts line
      end
      out.puts art_border
      @art_lines = nil
      state :md
    else
      @art_lines << take
    end
  end

  def md_code_fence
    lines = [ ]
    while peek
      case l = peek
      when l.lang.code_fence_rx
        take
        break
      else
        lines << l.assign_to(take)
      end
    end
    emit_code_lines lines, line_count: true
  end

  def code_line
    lines = [ ]
    while peek
      case l = peek
      when l.lang.code_line_rx
        lines << l.assign_to(take($1))
      else
        break
      end
    end
    emit_code_lines lines, line_count: true
    state :start
  end

  def code
    lines = [ ]
    while peek
      line = peek
      lang = line.lang
      case line
      when lang.head_rx, lang.text_rx, lang.md_begin_rx, lang.md_end_rx, lang.macro_rx, lang.meta_rx, lang.code_line_rx
        break
      else
        lines << line
        take
      end
    end
    emit_code_lines lines, line_count: true, lineno: true
    state :start
  end

  def macro
    lang = line.lang
    case line
    when lang.macro_rx, lang.meta_rx
      action, args = $1.to_sym, $2
      take
      case action
      when :MACRO
        macro_name = args.strip
        if macro_lines = @macros[macro_name]
          logger.info "  MACRO #{macro_name.inspect} : emitting #{macro_lines.size}"
          insert_lines macro_lines
        else
          raise "MACRO #{macro_name.inspect} undefined at: #{line.file}:#{line.lineno}"
        end
        state :start
      when :insert
        file_name = args.strip
        file_name.gsub!(/"/, '')
        file_name_abs = resolve_include(file_name)
        insert_file(file_name_abs)
        state :start
      when :include
        file_name = args.strip
        file_name.gsub!(/"/, '')
        file_name_abs = resolve_include(file_name)
        case state
        when :macro
          insert_file(file_name_abs)
          # insert_line("#{lang.text} #{file_name}:", lang)
        when :meta
          insert_line(lang.md_begin, lang)
          insert_file(file_name_abs)
          insert_line(lang.md_end,   lang)
        else
          raise line
        end
        state :start
      else
        raise line
      end
    else
      raise line
    end
  end

  def resolve_include file_name
    File.expand_path(file_name, input_dir)
  end

  def meta
    macro
  end

  ##############################

  def create_markdeep_html!
    write_html!("#{@output_file}.html", :markdeep)
  end

  def markdeep_footer
    <<END
+++++

<hr/>

<div class="ctmd-help">

code_to_markdeep Help

<div class="ctmd-help-navigation">

Navigation

| Button   | Key |  Action
|:--------:|:---:|:-----------------------------:
| ##       |     | Toggle section focus.
| ==       | \\  | Scroll section to top.
| &lt;&lt; | [   | Scroll to previous section.
| &gt;&gt; | ]   | Scroll to next section.
|          | "   | Unfocus section (show all).

</div>
END
  end

  def markdeep_html_header
    <<END
<!DOCTYPE html>
<!-- -*- mode: markdown; coding: utf-8; -*- -->
<html lang="en">
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="resource/markdeep/css/dark.css" orig-href="https://casual-effects.com/markdeep/latest/dark.css" />
<link rel="stylesheet" href="resource/ctmd/css/dark.css" />
<link rel="stylesheet" href="resource/ctmd/css/ctmd.css" />
<style>
body { font-family: sans-serif !important; }
h1, h2, h3, h4, h5, h6 { font-family: sans-serif !important; }
.md a:link, .md a:visited { font-family: sans-serif !important; }
</style>
#{@html_head.join("\n")}
</head>
<body style="visibility: hidden;">
END
  end

  def markdeep_html_footer
    <<"END"
</body>
<!-- ---------------------------------------------------------------------------- -->
<!-- Markdeep: -->
<style class="fallback">body{visibility:hidden;white-space:pre;font-family:monospace}</style>
<script src="resource/jquery/js/jquery-3.2.1.min.js" orig-src="https://code.jquery.com/jquery-3.2.1.min.js"></script>
<script src="resource/markdeep/js/markdeep.min.js" orig-src="https://casual-effects.com/markdeep/latest/markdeep.min.js"></script>
<script src="resource/ctmd/js/nav.js"></script>
#{@html_foot.join("\n")}
<script>window.alreadyProcessedMarkdeep||(document.body.style.visibility="visible")</script>
</html>
END
  end

  ##############################

  def create_reveal_html!
    write_html!("#{@output_file}.reveal.html", :reveal)
  end


  def reveal_footer
  end

  def reveal_html_header
    <<END
<html>
	<head>
		<link rel="stylesheet" href="../local/reveal.js/css/reveal.css">
		<link rel="stylesheet" href="../local/reveal.js/css/theme/white.css">
	</head>
	<body>
		<div class="reveal">
                   <section data-markdown>
                     <textarea data-template>

END
  end

  def reveal_html_footer
    <<END
<!-- ---------------------------------------------------------------------------- -->
<!-- Reveal.js markdown: -->
                     </textarea>
                   </section>
		</div>
		<script src="../local/reveal.js/js/reveal.js"></script>
		<script>
			Reveal.initialize();
		</script>
	</body>
</html>
END
  end

  ##############################

  def create_jqp_html!
    @jqp_dir = "../local/jQuery-Presentation"
    @jqp_css = "#{@jqp_dir}/stylesheets"
    @jqp_js  = "#{@jqp_dir}/scripts"
    write_html!("#{@output_file}.jqp.html", :jqp) do | input, output |
    end
  end


  def jqp_html_header
    <<END
<html>
	<head>
		<link rel="stylesheet" href="../local/reveal.js/css/reveal.css">
		<link rel="stylesheet" href="../local/reveal.js/css/theme/white.css">
	</head>
	<body>
		<div class="reveal">
                   <section data-markdown>
                     <textarea data-template>

END
  end

  def jqp_footer
  end

  def jqp_html_footer
    <<END
<!-- ---------------------------------------------------------------------------- -->
<!-- Reveal.js markdown: -->
                     </textarea>
                   </section>
		</div>
		<script src="../local/reveal.js/js/reveal.js"></script>
		<script>
			Reveal.initialize();
		</script>
	</body>
</html>
END
  end

  ##############################

  def write_html! html, kind, &blk
    logger.info "writing #{html}"
    File.open(html, "w") do | out |
      out.puts send(:"#{kind}_html_header")
        File.open(@output_file) do | md |
        if blk
          blk.call(md, out)
        else
          until md.eof?
            out.write(md.read(8192))
          end
        end
      end
      out.puts send(:"#{kind}_footer")
      out.puts send(:"#{kind}_html_footer")
    end
    logger.info "writing #{html} : DONE"
  end

  attr_reader :args, :exitcode
  attr_reader :input_file, :input_dir, :output_file, :output_dir

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

  def copy_resources!
    base_dir = DIR
    src_dir = "#{base_dir}/resource"
    src_files = "#{src_dir}/**/*"
    src_files = Dir[src_files]
    # ap(src_files: src_files)
    src_files.reject{|p| File.directory?(p)}.each do | src_file |
      dst_file = src_file.sub(%r{^#{base_dir}/}, output_dir + '/')
      logger.info "copying #{src_file} to #{dst_file}"
      FileUtils.mkdir_p(File.dirname(dst_file))
      FileUtils.cp(src_file, dst_file)
    end
    self
  end

  def lang_state lang
    @lang_state[lang.name] ||= { }
  end
  
  def process!
    @input_file  = args[0]
    @output_file = args[1]
    @verbose = (ENV['C_TO_MD_VERBOSE'] || 0).to_i
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

    insert_file(@input_file)
    logger.info "writing #{@output_file}"
    File.open(@output_file, "w") do | out |
      @out = out
      parse!
    end
    logger.info "writing #{@output_file} : DONE"

    create_markdeep_html!
    # create_reveal_html!
    copy_resources!
    self
  end
end
end

