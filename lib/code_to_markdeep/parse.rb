# frozen_string_literal: true

require 'code_to_markdeep'

module CodeToMarkdeep
  module Parse
    def state new_state = nil
      @state = new_state if new_state
      @state
    end

  def parse!
    state :start
    while @line = peek
      log :parse! if verbose >= 2
      # binding.pry
      send(state)
    end
  end

  # Start state:
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
    when lang.md_begin_rx
      take
      state :md
    when lang.macro_rx
      state :macro
    when lang.meta_rx
      state :meta
    when lang.head_rx
      take
      state :head
    when lang.text_rx
      out.puts ""
      state :text
    when lang.code_line_rx
      state :code_line
    when lang.html_rx
      out.puts line
      take
    else
      state :code
    end
  end


  end
end


