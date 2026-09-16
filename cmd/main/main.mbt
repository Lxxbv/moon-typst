///|
/// Command Line Interface for moon-typst compiler and renderer

fn print_help() -> Unit {
  let help_text =
    #|moon-typst: High-performance Typst markup parser and renderer in MoonBit
    #|
    #|Usage:
    #|  typst-render [OPTIONS] <input.typ>
    #|
    #|Options:
    #|  -o, --output <FILE>   Specify output file path (default: input.svg or input.html)
    #|  --html                Render to semantic HTML5 document (default is SVG)
    #|  --svg                 Render to vector SVG graphics (default)
    #|  -h, --help            Print help information
    #|  -v, --version         Print version information
    #|
    #|Examples:
    #|  typst-render paper.typ -o paper.svg
    #|  typst-render report.typ --html -o report.html
  println(help_text)
}

fn print_version() -> Unit {
  println("moon-typst v0.1.0 (MoonBit Typst Engine)")
}

fn main {
  let args = @env.args()
  if args.length() <= 1 {
    print_help()
    return
  }

  let mut input_path = ""
  let mut output_path = ""
  let mut format_html = false

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
    if arg == "--html" {
      format_html = true
      i = i + 1
      continue
    }
    if arg == "--svg" {
      format_html = false
      i = i + 1
      continue
    }
    if arg == "-o" || arg == "--output" {
      if i + 1 < args.length() {
        output_path = args[i + 1]
        i = i + 2
        continue
      } else {
        println("Error: Missing argument for output option")
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
    println("Error: Input file not found: \{input_path}")
    return
  }

  // Derive default output path if not specified
  let target_output = if output_path.length() > 0 {
    output_path
  } else if format_html {
    if input_path.has_suffix(".typ") {
      input_path[0:input_path.length() - 4].to_owned() + ".html"
    } else {
      input_path + ".html"
    }
  } else {
    if input_path.has_suffix(".typ") {
      input_path[0:input_path.length() - 4].to_owned() + ".svg"
    } else {
      input_path + ".svg"
    }
  }

  // Read input file
  let content = try {
    @fs.read_file_to_string(input_path)
  } catch {
    @fs.IOError(err) => {
      println("Error reading file: \{err}")
      return
    }
  }

  println("[moon-typst] Parsing \{input_path}...")
  let doc = @parser.parse_typst(content)
  println("[moon-typst] Parsed \{doc.blocks.length()} blocks successfully.")

  if format_html {
    println("[moon-typst] Rendering to semantic HTML5...")
    let html_content = @render.render_html(doc)
    try {
      @fs.write_string_to_file(target_output, html_content)
      println("[moon-typst] Successfully generated: \{target_output}")
    } catch {
      @fs.IOError(err) => println("Error writing output file: \{err}")
    }
  } else {
    println("[moon-typst] Computing layout and box geometry...")
    let style = @core.StyleContext::default()
    let engine = @layout.LayoutEngine::new(style)
    let page = engine.layout_doc(doc)
    println("[moon-typst] Generated \{page.boxes.length()} layout boxes.")

    println("[moon-typst] Rendering to vector SVG...")
    let svg_content = @render.render_svg(page)
    try {
      @fs.write_string_to_file(target_output, svg_content)
      println("[moon-typst] Successfully generated: \{target_output}")
    } catch {
      @fs.IOError(err) => println("Error writing output file: \{err}")
    }
  }
}
