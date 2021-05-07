require 'code_to_markdeep'

module CodeToMarkdeep
  module Meta
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
