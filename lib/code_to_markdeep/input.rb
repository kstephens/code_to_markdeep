# frozen_string_literal: true

require 'code_to_markdeep'

module CodeToMarkdeep
  module Input
    def self.included target
      super
      INITS << :input_initialize
    end

    attr_reader :input_file, :input_dir
    attr_reader :line, :lines, :lineno, :source_files
    
    def input_initialize *args
      @lineno = 0
      @lines = [ ]
      @lines_taken = 0
      @lang_state = { }
      @source_files = { }
    end

    def read_input_file! file
      @input_file  = file
      @input_dir  = File.dirname(File.expand_path(@input_file))

      lang = Lang.from_file(@input_file)
      input_line = "<<#{@input_file}>>".freeze
      input_line = Line.new(input_line, original: input_line, lang: lang)
      insert_file(@input_file, input_line)
    end
    
    ######################################
    
    def lang_state lang
      @lang_state[lang.name] ||= { }
    end

  def take # val = nil
    line = peek
    @peek = nil
    log :take if verbose >= 3
    @lines_taken += 1 if line
    line
  end

  def peek
    unless @peek
      log :peek if verbose >= 4
      @peek = _peek
    end
    log "peek => #{@peek}" if verbose >= 4
    @log_line = @peek
  end

  def _peek
    while true
      line = __take
      log :_peek if verbose >= 5
      
      var = nil
      capture_macro = true

      unless line
        unless @eof
          logger.info "peek: EOF after #{@lines_taken} lines"
          @eof = true
        end
        return nil
      end

      # HACK:
      # See Meta#parse_hidden_directive for
      # an alternative:
      line = parse_hidden_directive(line)
      lang = line.lang

      case
      when line == :next
        next
      when line.lang.editor_annotation_rx.match(line.to_s)
        log :editor_annotation if verbose >= 6
      when line.lang.name == :Markdown
        log :Markdown_line if verbose >= 6
        if @macro
          log :macro_line if verbose >= 6
          @macro << line
        else
          return line
        end
      when parse_variable_directive(line)
        log :variable_directive if verbose >= 6
      when m = line.lang.meta_eol_rx.match(line.to_s)
        meta_eol line, m
      when line.lang.hidden_rx.match(line.to_s)
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

      log :_peek_again if verbose >= 5
    end
  end

  def __take
    @log_line = @lines.shift
  end

  def __peek
    @log_line = @lines.first
  end

  def insert_file file, included_by # = nil
    file = file.strip.gsub(/"/, '')
    path = resolve_include(file)
    lines = [ ]
    @lineno = 0
    lang = Lang.from_file(file)
    # binding.pry if file =~ /\.scm/
    # lines << Line.new("//$ BEGIN LANG #{lang.name}", file: file, lineno: 0, lang: lang)
    default_line = "*MAIN*"
    included_by ||= Line.new(default_line, original: default_line, lang: lang)
    source_file = @source_files[file] ||= SourceFile.new(file, path, lang, included_by)
    File.open(file) do | inp |
      until inp.eof?
        @lineno += 1
        line = inp.readline.chomp
        line = Line.new(line, file: file, lineno: lineno, lang: lang, source_file: source_file)
        lines.push(line)
      end
    end
    # lines << Line.new("//$ END LANG", original: line, file, lineno + 1)
    insert_lines lines
  end

  def last_line ; @lines.last ; end

  def insert_lines lines
    @lines = lines + @lines
  end
  
  def insert_line line, lang
    @lines.unshift Line.new(line, original: line, lang: lang)
  end


  end
end

