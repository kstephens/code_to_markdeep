require 'code_to_markdeep'

module CodeToMarkdeep
  module Art
    def art
      @art_lines ||= [ ]
      case line = take
      when line.lang.art_rx
        emit_art! @art_lines
        @art_lines = nil
        state :md
      else
        @art_lines << line
      end
    end

    def emit_art! lines
      # Prepend '* ' to each line, if missing.
      lines.map! do | line |
        line =~ /^\* / ? line : '* ' + line
      end

      # Calc width of fence:
      width = lines.map(&:size).max + 2
      art_border = '*' * width

      # Add fence:
      lines.unshift art_border
      lines.push    art_border

      # Expand lines to fence width:
      lines.map! do | line |
        "%-#{width}s*" % [line.to_s]
      end

      lines.each{|l| out.puts l}
    end
  end
end
