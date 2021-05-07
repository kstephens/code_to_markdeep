require 'code_to_markdeep'

module CodeToMarkdeep
  module Output
    def emit_text str, line = str
      str = str.to_s.gsub(RX_var_ref) do | m |
        # logger.debug "str = #{str.inspect} $1=#{$1.inspect}"
        @vars[$1.to_sym] || lang_state(line.lang)[$1.to_sym]
      end
      out.puts str
    end

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

  def copy_resources!
    base_dir = DIR
    src_dir = "#{base_dir}/resource"
    src_files = "#{src_dir}/**/*"
    src_files = Dir[src_files]
    # ap(src_files: src_files)
    src_files.reject{|p| File.directory?(p)}.each do | src_file |
      dst_file = src_file.sub(%r{^#{base_dir}/}, output_dir + '/')
      dst_dir = File.dirname(dst_file)
      logger.info "cp #{src_file} #{dst_file}"
      unless File.exist? dst_dir
        logger.info "mkdir #{dst_dir}"
        FileUtils.mkdir_p(dst_dir)
      end
      FileUtils.cp(src_file, dst_file)
    end
    self
  end

    ###################################
    
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

Made with Markdeep:

http://casual-effects.com/markdeep/

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
<link rel="stylesheet" href="resource/markdeep/css/dark.css"
                  orig-href="https://casual-effects.com/markdeep/latest/dark.css" />
<link rel="stylesheet" href="resource/ctmd/css/dark.css" />
<link rel="stylesheet" href="resource/ctmd/css/ctmd.css" />
<link rel="stylesheet" href="resource/css/doc.css" /> <!-- Optional: but must exist -->
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

<!-- ------------------------------------------------------- -->

<!-- 
<style class="fallback">
body {
  visibility:  hidden;
  white-space: pre;
  font-family: monospace;
}
</style>
 -->

<!-- ------------------------------------------------------- -->

<script src="resource/jquery/js/jquery-3.2.1.min.js"
   orig-src="https://code.jquery.com/jquery-3.2.1.min.js"></script>
<script src="resource/markdeep/js/markdeep.min.js"
   orig-src="https://casual-effects.com/markdeep/latest/markdeep.min.js"></script>

<!-- ------------------------------------------------------- -->
<script src="resource/ctmd/js/core.js"></script>
<script src="resource/ctmd/js/nav.js"></script>
<script src="resource/js/doc.js"></script> <!-- optional: but must exist -->
#{@html_foot.join("\n")}
<script>
window.alreadyProcessedMarkdeep || (document.body.style.visibility="visible")
</script>
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

  end
end

