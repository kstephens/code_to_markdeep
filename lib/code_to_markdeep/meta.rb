require 'code_to_markdeep'

module CodeToMarkdeep
  RX_var_ref    = /\{\{(\w+)\}\}/

  module Meta
    def self.included target
      super
      INITS << :meta_initialize
    end

    attr_reader :vars, :var
    attr_reader :dec_var # UNUSED?

    def meta_initialize *args
      @vars       = { }
      @vars_stack = Hash.new{|h,k| h[k] = [ ]}
      @macros     = { }
      @macro_stack = [ ]
    end

    def parse_hidden_directive line
      case
      when line.lang.hidden_comment_begin_rx
        Line.new("//$ BEGIN HIDDEN", original: line)
      when line.lang.hidden_comment_end_rx
        Line.new("//$ END HIDDEN"  , original: line)
      when is_ignore_line?(line)
        :next
      else
        line
      end
    end

    def is_ignore_line? line
      Array(@vars[:IGNORE_RX]).compact.any? do |rx_str|
        cache_regex(rx_str) === line
      end
    end
    
    def parse_variable_directive line
      case
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
      else
        return false
      end
      line
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
          insert_file(args, line)
          state :start
        when :include
          case state
          when :macro
            insert_file(args, line)
            # insert_line("#{lang.text} #{file_name}:", lang)
          when :meta
            insert_line(lang.md_begin, lang)
            # binding.pry if file_name_abs =~ /\.scm$/
            insert_file(args, line)
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

    def meta_eol line, match
      pre_cmd = match[1]
      cmd  = match[2].to_sym
      args = match[3].split(/\s+/)
      case cmd
      when :include
        file_name = pre_cmd.strip.split(/\s+/)[-1]
        # binding.pry
        case args[0]
        when "HIDDEN"
        else
          insert_lines [Line.new(pre_cmd, original: line)]
        end
        insert_file(file_name, line)
      else
        logger.warn "meta_eol: invalid command: #{line.inspect}"
      end
    end

    def resolve_include file_name
      File.expand_path(file_name, input_dir)
    end

    def meta
      macro
    end
  end
end
