///|
/// Command Line Interface for moon-typst compiler and multi-target renderer
fn print_help() -> Unit {
  let help_text =
    #|moon-typst: High-performance Typst markup parser, layout engine, and multi-format renderer in MoonBit
    #|
    #|Usage:
    #|  typst-render [OPTIONS] <input.typ>
    #|
    #|Options:
    #|  -o, --output <FILE>   Specify output file path (default: input.svg, input.pdf, or input.html)
    #|  -p, --pdf             Render to standard PDF 1.4 binary document
    #|  --svg                 Render to vector SVG graphics (default)
    #|  --html                Render to semantic HTML5 document
    #|  --no-color            Disable ANSI color escapes in diagnostic messages
    #|  -h, --help            Print help information
    #|  -v, --version         Print version information
    #|
    #|Examples:
    #|  typst-render paper.typ -p -o paper.pdf
    #|  typst-render report.typ --html -o report.html
    #|  typst-render diagram.typ --svg -o diagram.svg
  println(help_text)
}

///|
fn print_version() -> Unit {
  println("moon-typst v0.2.0 (MoonBit Typst Compiler & Multi-Target Vector Engine)")
}

///|
pub enum OutputFormat {
  Svg
  Pdf
  Html
} derive(Eq, Debug)

///|
fn main {
  let args = @env.args()
  if args.length() <= 1 {
    print_help()
    return
  }

  let mut input_path = ""
  let mut output_path = ""
  let mut format = OutputFormat::Svg
  let mut format_explicit = false
  let mut use_color = true

  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "-h" || arg == "--help" {
      print_help()
      return
    }
    if arg == "-v" || arg == "--version" {
      print_version()
      return
    }
    if arg == "--no-color" {
      use_color = false
      i = i + 1
      continue
    }
    if arg == "-p" || arg == "--pdf" {
      format = OutputFormat::Pdf
      format_explicit = true
      i = i + 1
      continue
    }
    if arg == "--html" {
      format = OutputFormat::Html
      format_explicit = true
      i = i + 1
      continue
    }
    if arg == "--svg" {
      format = OutputFormat::Svg
      format_explicit = true
      i = i + 1
      continue
    }
    if arg == "-o" || arg == "--output" {
      if i + 1 < args.length() {
        output_path = args[i + 1]
        i = i + 2
        continue
      } else {
        println("Error: Missing argument for output option (-o / --output)")
        return
      }
    }
    if input_path.length() == 0 && !arg.has_prefix("-") {
      input_path = arg
      i = i + 1
      continue
    }
    i = i + 1
  }

  if input_path.length() == 0 {
    println("Error: No input .typ file specified.")
    print_help()
    return
  }

  if !@fs.path_exists(input_path) {
    let reporter = @diag.DiagnosticReporter::new(input_path, "")
    reporter.add(
      @diag.Diagnostic::error(
        "Input file not found: " + input_path,
        @diag.Span::empty(),
      ).with_hint("Please check the file path and ensure it exists."),
    )
    println(reporter.render_all(use_color))
    return
  }

  // Auto-detect format from output extension if format not explicitly specified
  if !format_explicit && output_path.length() > 0 {
    if output_path.has_suffix(".pdf") {
      format = OutputFormat::Pdf
    } else if output_path.has_suffix(".html") || output_path.has_suffix(".htm") {
      format = OutputFormat::Html
    } else if output_path.has_suffix(".svg") {
      format = OutputFormat::Svg
    }
  }

  // Derive default output path if not provided
  let target_output = if output_path.length() > 0 {
    output_path
  } else {
    let stem = if input_path.has_suffix(".typ") {
      input_path[0:input_path.length() - 4].to_owned()
    } else {
      input_path
    }
    match format {
      OutputFormat::Pdf => stem + ".pdf"
      OutputFormat::Html => stem + ".html"
      OutputFormat::Svg => stem + ".svg"
    }
  }

  // Read input file
  let content = @fs.read_file_to_string(input_path) catch {
    @fs.IOError(err) => {
      let reporter = @diag.DiagnosticReporter::new(input_path, "")
      reporter.add(
        @diag.Diagnostic::error(
          "Failed to read file: " + err,
          @diag.Span::empty(),
        ),
      )
      println(reporter.render_all(use_color))
      return
    }
  }

  let reporter = @diag.DiagnosticReporter::new(input_path, content)
  let base_style = @core.StyleContext::default()
  let evaluator = @eval.Evaluator::new(base_style, reporter)

  println("[moon-typst] Compiling: \{input_path}")
  let doc = @parser.parse_typst(content)
  println("[moon-typst] Abstract Syntax Tree: \{doc.blocks.length()} root blocks")

  match format {
    OutputFormat::Html => {
      println("[moon-typst] Target: Semantic HTML5 document")
      let html_content = @render.render_html(doc)
      try {
        @fs.write_string_to_file(target_output, html_content)
        println("[moon-typst] Successfully wrote: \{target_output}")
      } catch {
        @fs.IOError(err) =>
          println("[moon-typst] Error writing \{target_output}: \{err}")
      }
    }
    OutputFormat::Pdf => {
      println("[moon-typst] Target: Adobe PDF 1.4 Binary Document")
      println("[moon-typst] Executing layout engine & font metrics...")
      let engine = @layout.LayoutEngine::new(evaluator.style)
      let page = engine.layout_doc(doc)
      println(
        "[moon-typst] Layout computed: \{page.boxes.length()} boxes (Page size: \{page.width}x\{page.height} pt)",
      )
      println("[moon-typst] Serializing PDF xref tables, streams, and font dicts...")
      let pdf_content = @render.render_pdf(page)
      try {
        @fs.write_string_to_file(target_output, pdf_content)
        println(
          "[moon-typst] Successfully generated: \{target_output} (\{pdf_content.length()} bytes)",
        )
      } catch {
        @fs.IOError(err) =>
          println("[moon-typst] Error writing \{target_output}: \{err}")
      }
    }
    OutputFormat::Svg => {
      println("[moon-typst] Target: Vector SVG Graphics")
      println("[moon-typst] Executing layout engine & box geometry...")
      let engine = @layout.LayoutEngine::new(evaluator.style)
      let page = engine.layout_doc(doc)
      println(
        "[moon-typst] Layout computed: \{page.boxes.length()} boxes (ViewBox: 0 0 \{page.width} \{page.height})",
      )
      println("[moon-typst] Serializing vector paths, text nodes, and styles...")
      let svg_content = @render.render_svg(page)
      try {
        @fs.write_string_to_file(target_output, svg_content)
        println(
          "[moon-typst] Successfully generated: \{target_output} (\{svg_content.length()} bytes)",
        )
      } catch {
        @fs.IOError(err) =>
          println("[moon-typst] Error writing \{target_output}: \{err}")
      }
    }
  }

  if reporter.diagnostics.length() > 0 {
    println("")
    println(reporter.render_all(use_color))
  }
}

