require 'code_to_markdeep'

module CodeToMarkdeep
  module Input
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
    @line = @peek
  end

  def cache_regex str
    str and
      (@rx_cache ||= {})[str] ||= Regexp.new(str)
  end

  def _peek
    while true
      line = __take
      log :_peek if verbose >= 5

      # HACK:
      lang = line && line.lang
      case line
      when nil
      when lang && lang.hidden_comment_begin_rx
        line = Line.new("//$ BEGIN HIDDEN", original: line)
      when lang && lang.hidden_comment_end_rx
        line = Line.new("//$ END HIDDEN"  , original: line)
      else
        next if Array(@vars[:IGNORE_RX]).compact.any? do |rx_str|
          cache_regex(rx_str) === line
        end
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
      when line.lang.emacs_rx.match(line.to_s)
      when line.lang.name == :Markdown
        if @macro
          @macro << line
        else
          return line
        end
      when line.lang.set_rx.match(line.to_s)
        var = $1.to_sym
        val = $2
        # $stderr.puts "SET #{var.inspect} #{val.inspect}"
        @vars[var] = val
      when line.lang.append_rx.match(line.to_s)
        binding.pry unless $1
        var = $1.to_sym
        val = $2
        @vars[var] = Array(@vars[var])
        @vars[var] << val
      when line.lang.begin_rx.match(line.to_s)
        var = $1.to_sym
        val = $2
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
      when line.lang.end_rx.match(line.to_s)
        var = $1.to_sym
        @vars = @vars.dup
        val = @vars[var] = @vars_stack[var].pop
        case var
        when :MACRO
          logger.info "  MACRO #{macro_name} : #{@macro.size} lines"
          @macro = @macro_stack.pop
        end
        # ap(var: var, val: val, line: line.info) if var == :LINENO
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
    end
  end

  def __take
    @lines.shift
  end

  def __peek
    @lines.first
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

