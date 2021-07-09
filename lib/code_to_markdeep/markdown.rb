# frozen_string_literal: true

require 'code_to_markdeep'

module CodeToMarkdeep
  module Markdown
    def text
      case line
      when line.lang.text_rx
        take
        emit_text $2, line
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
        # binding.pry if line =~ %r{^\<\|\#}
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

    def md_code_fence
      lines = [ ]
      while peek
        case l = peek
        when l.lang.code_fence_rx
          take
          break
        else
          line = take
          lines << Line.new(line)
        end
      end
     emit_code_lines lines, line_count: true
   end


  end
end

