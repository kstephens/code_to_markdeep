require 'code_to_markdeep'

module CodeToMarkdeep
  #### A description of a programming language
  class Lang
    LANG = { }
    TAG  = { }
    def self.[] name
      LANG[name.to_sym]
    end
    
    def self.from_file file
      LANG.values.find {|l| l.file_name_rx =~ file } || LANG[:C]
    end
    
    attr_reader :name
    def initialize opts
      @opts = opts
      @opts.each do | k, v |
        instance_variable_set(:"@#{k}", v)
      end
      @name or raise "no :name"
      C_attrs.each do | k, v |
        if ! @opts.key?(k) && Regexp === v
          instance_variable_set(:"@#{k}", convert_rx(v, k))
        end
      end
      @md_end    ||= @md_begin     if @md_begin
      @md_end_rx ||= @md_begin_rx  if @md_begin_rx
      @gfm_language ||= @name.to_s
      TAG[@tag] ||= self
      LANG[@name] ||= self
    end
    
    def inspect full = false
      if full
        super()
      else
        "Lang[#{@name.inspect}]"
      end
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
      if comment_line
        s = comment_line[0]
        s = rx.to_s.gsub(%r{\\/}, s)
        Regexp.new(s)
      else
        rx
      end
    end

    C_attrs = {
      name:           :C,
      gfm_language:   "C",
      tag:            "/",
      file_name_rx:   /\.[ch]$/,
      comment_begin:  "/*",
      comment_end:    "*/",
      comment_line:   "//",
      hidden_comment_begin_rx:  %r{^#if\s+0},
      hidden_comment_end_rx:    %r{^#endif\s*(//\s*0|/\*\s*0\s*\*/)},
      text:           "/// ",
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
      set_rx:       %r{//\$\s*SET\s+(\w+)(?:\s+(\S*))?},
      append_rx:    %r{//\$\s*APPEND\s+(\w+)(?:\s+(\S*))?},
      hidden_rx:    %r{//\$\s*HIDDEN},
      meta_eol_rx:  %r{^(.+?)//\!(\w+)\s*(.*)},

      head_rx:      %r{^///////////+\s*$},
      text_rx:      %r{^//(/+) (.*)},
      macro_rx:     %r{^//\#(\w+)\s*(.*)},
      meta_rx:      %r{^//\!(\w+)\s*(.*)},
      md_begin:     "/\*/",
      md_begin_rx:  %r{^\s*/\*/},
      md_end:       "/\*/",
      md_end_rx:    %r{^\s*/\*/},
      comment_line_rx: %r{^\s*//},
      code_line_rx: %r{^//~(\S*) (.*)},
    }
    attr_reader *C_attrs.keys
    # alias :md_end_rx :md_begin_rx
    # alias :md_end    :md_begin

    def describe
      patterns = C_attrs.keys.map do | attr |
        [ attr, send(attr) ]
      end
      {
        name: name,
        patterns: Hash[patterns],
      }.ai
    end
    
    # new(name: :C)
    new(C_attrs)
    new(name: :Markdown,
        file_name_rx:   /(\.md$)/,
        )
    new(name: :Ruby,
        file_name_rx:   /(Rakefile|Gemfile|Guardfile|\.rb$)/,
        comment_begin:  "#",
        comment_end:    "#",
        comment_line:   "#",
        hidden_comment_begin_rx:  %r{^=begin},
        hidden_comment_end_rx:    %r{^=end},
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
        tag:           ";",
        gfm_language:  'scheme',
        file_name_rx:   /\.(s(cm)?|rkt)$/,
        comment_begin:  "#|",
        comment_end:    "|#",
        comment_line:   ";;",
        hidden_comment_begin_rx:  nil,
        hidden_comment_end_rx:    nil,
        text:           ";;; ",
        md_begin:       "#|>",
        md_begin_rx:    %r{^\s*\#\|\>\s*$},
        md_end:         "<|#",
        md_end_rx:      %r{^\s*\<\|\#\s*$},
        text_rx:        %r{^;;(;+) (.*)},
        html_rx:        nil,
        code_line_rx:   %r{^;;~(\S*) (.*)},
        convert_rx_f: lambda do | rx, k |
          # binding.pry
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
end
