# frozen_string_literal: true

require 'code_to_markdeep'

module CodeToMarkdeep
  module Code
    def code_line
      lines = [ ]
      while peek
        case l = peek
        when l.lang.code_line_rx
          tag, txt = $1, $2
          txt = Line.new(txt, original: take)
          txt.lang = Lang::TAG[tag] || l.lang
          lines << txt
        else
          break
        end
      end
      emit_code_lines lines # , line_count: true
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


    def fmt_code_line line
      lang = line.lang
      lstate = lang_state(lang)
      show_lineno = false
      lstate[:code_lineno] ||= 0
      @lineno_fmt ||= "%%Li_%4s_nE%%"
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

    def fmt_code line_, opts = nil
      opts ||= Empty_Hash
      max_line_length = 60
      line = line_.rstrip
      case line
      when %r{^ox_[^(]+\([^)]+\)\s*;} # FIXME: this doesn't belong here:
        unless line.size <= max_line_length
          if %r{\A(.*?)(\s*/[/*].*)\Z}.match(line) # FIXME: C specific comment
            line, trailing_comment = $1, $2
          else
            trailing_comment = ''
          end
          line = word_break(line, max_line_length) + trailing_comment
          # line.chomp ??
          # logger.debug { "   #{state} |\n#{_multiline! line_}| => |#{_multiline! line}|" }
        end
      end
      line = Line.new(line_)
      line = fmt_code_line(line) if opts[:lineno]
      line
    end

    def word_break line_, max_len = 80
      line = line_
      if line.size > max_len
        m = %r{\A(.*,)?(.*)?\Z}.match(line)
        if false
          logger.debug { "  m[1] = #{m[1].size} | #{m[1].inspect}" }
          logger.debug { "  m[2] = #{m[2].size} | #{m[2].inspect}" }
        end
        args   = word_break_(m[1] || '', max_len, %r{([^,]*,)})
        stmts  = word_break_(m[2] || '', max_len, %r{([^;]*;)})
        line = args
        line << "\n  " << stmts if stmts.size > 0
        if line != line_ && false
          msg = "/* ORIG: #{line_.size} : #{line_} */\n  /* NEW: #{line.size} */\n"
          logger.debug { "  word_break : |\n#{msg}" }
          line = msg << line
        end
      end
      line
    end

    def word_break_ line_, max_len, token_rx
      line = line_
      return line if line.size <= max_len
      tokens = [ ''.dup ]
      acc = ''.dup
      while ! line.empty? and m = token_rx.match(line)
        before, token, line = $`, $1, $'
        # logger.debug { "  #{before.inspect} | #{token.inspect} | #{line.size}" }
        acc << before
        if acc.size > max_len
          tokens << acc
          acc = ''.dup
        end
        acc << token
        if acc.size > max_len
          tokens << acc
          acc = ''.dup
        end
      end
      if (acc << line).size < 8 # HARD-CODED
        tokens[-1] << acc
      else
        tokens << acc
      end
      tokens = tokens.reject(&:nil?).each(&:strip!).reject(&:empty?)
      # logger.debug { "  token lengths: #{tokens.map(&:size).inspect}" }
      longest = tokens.map(&:size).max
      fmt = "%-#{longest}s"
      tokens.map!{|l| fmt % [ l ]}
      # logger.debug { "  token lengths: #{tokens.map(&:size).inspect}" }
      sep = " \n  "
      # sep = " \\ \n  "
      line = tokens.join(sep)
      if false and line != line_
        logger.debug { "  word_break_ #{token_rx}: |\n#{_multiline! line_} => #{_multiline! line}|" }
      end
      line
    end

    def _multiline! str, anchor = '~~~'
      str = str.to_s.gsub("\n", "\n#{anchor} ")
      "\n#{anchor}{\n#{str}\n#{anchor}}\n"
    end

    def _multiline str, anchor = '~~~'
      str = str.to_s
      if str.index("\n")
        _multiline! str, anchor
      else
        str
      end
    end

    def code_fence line = nil
      case line
      when nil
        "```\n"
      else
        "\n```#{line.lang.gfm_language}\n"
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

  end
end

