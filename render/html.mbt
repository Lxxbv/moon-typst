///|
/// Semantic HTML5 document generator for Typst documents

///|
/// Render a Doc AST into clean semantic HTML5
pub fn render_html(doc : @core.Doc) -> String {
  let buf = StringBuilder()
  buf.write_string("<!DOCTYPE html>\n")
  buf.write_string("<html lang=\"en\">\n")
  buf.write_string("<head>\n")
  buf.write_string("  <meta charset=\"UTF-8\"/>\n")
  buf.write_string(
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"/>\n",
  )
  buf.write_string("  <title>Typst Document</title>\n")
  buf.write_string("  <style>\n")
  buf.write_string(
    "    body { margin: 0; padding: 24px; background: #f6f8fa; font-family: system-ui, -apple-system, sans-serif; }\n",
  )
  buf.write_string(
    "    .typst-doc { max-width: 800px; margin: 0 auto; background: #ffffff; padding: 48px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); color: #1f2328; line-height: 1.6; }\n",
  )
  buf.write_string(
    "    h1 { font-size: 2em; border-bottom: 1px solid #d8dee4; padding-bottom: .3em; margin-top: 24px; }\n",
  )
  buf.write_string(
    "    h2 { font-size: 1.5em; border-bottom: 1px solid #d8dee4; padding-bottom: .3em; margin-top: 20px; }\n",
  )
  buf.write_string("    h3 { font-size: 1.25em; margin-top: 16px; }\n")
  buf.write_string("    p { margin: 12px 0; }\n")
  buf.write_string(
    "    code { background: #eff1f3; padding: .2em .4em; border-radius: 4px; font-size: 85%; font-family: ui-monospace, Consolas, monospace; color: #cf222e; }\n",
  )
  buf.write_string(
    "    pre { background: #f6f8fa; padding: 16px; border-radius: 6px; overflow: auto; border: 1px solid #d0d7de; }\n",
  )
  buf.write_string(
    "    pre code { background: none; padding: 0; color: #1f2328; font-size: 90%; }\n",
  )
  buf.write_string(
    "    .math-block { text-align: center; padding: 16px; margin: 16px 0; background: #fcfcfd; border: 1px solid #e1e4e8; border-radius: 6px; font-family: 'Times New Roman', Cambria, serif; font-size: 1.2em; }\n",
  )
  buf.write_string(
    "    .math-inline { font-family: 'Times New Roman', Cambria, serif; font-style: italic; padding: 0 2px; }\n",
  )
  buf.write_string(
    "    .frac { display: inline-flex; flex-direction: column; vertical-align: middle; text-align: center; padding: 0 4px; font-size: 0.9em; }\n",
  )
  buf.write_string(
    "    .num { border-bottom: 1px solid #1f2328; padding-bottom: 2px; }\n",
  )
  buf.write_string("    .den { padding-top: 2px; }\n")
  buf.write_string(
    "    table { border-collapse: collapse; width: 100%; margin: 16px 0; }\n",
  )
  buf.write_string(
    "    td, th { border: 1px solid #d0d7de; padding: 8px 12px; }\n",
  )
  buf.write_string("    ul, ol { padding-left: 2em; margin: 12px 0; }\n")
  buf.write_string("    li { margin: 4px 0; }\n")
  buf.write_string(
    "    hr { height: .25em; padding: 0; margin: 24px 0; background-color: #d0d7de; border: 0; }\n",
  )
  buf.write_string("    a { color: #0969da; text-decoration: none; }\n")
  buf.write_string("    a:hover { text-decoration: underline; }\n")
  buf.write_string("  </style>\n")
  buf.write_string("</head>\n")
  buf.write_string("<body>\n")
  buf.write_string("  <div class=\"typst-doc\">\n")

  for block in doc.blocks {
    render_html_block(buf, block)
  }

  buf.write_string("  </div>\n")
  buf.write_string("</body>\n")
  buf.write_string("</html>\n")
  buf.to_string()
}

///|
fn render_html_block(buf : StringBuilder, block : @core.Block) -> Unit {
  match block {
    @core.Block::Heading(level, inlines) => {
      let lvl = if level >= 1 && level <= 6 { level } else { 1 }
      buf.write_string("    <h\{lvl}>")
      render_html_inlines(buf, inlines)
      buf.write_string("</h\{lvl}>\n")
    }
    @core.Block::Paragraph(inlines) => {
      buf.write_string("    <p>")
      render_html_inlines(buf, inlines)
      buf.write_string("</p>\n")
    }
    @core.Block::CodeBlock(lang, code) => {
      let lang_class = if lang.length() > 0 {
        " class=\"language-\{lang}\""
      } else {
        ""
      }
      buf.write_string("    <pre><code\{lang_class}>")
      buf.write_string(escape_xml(code))
      buf.write_string("</code></pre>\n")
    }
    @core.Block::MathBlock(expr) => {
      buf.write_string("    <div class=\"math-block\">")
      render_html_math(buf, expr)
      buf.write_string("</div>\n")
    }
    @core.Block::List(ordered, items) => {
      let tag = if ordered { "ol" } else { "ul" }
      buf.write_string("    <\{tag}>\n")
      for item in items {
        buf.write_string("      <li>")
        render_html_inlines(buf, item)
        buf.write_string("</li>\n")
      }
      buf.write_string("    </\{tag}>\n")
    }
    @core.Block::Table(cols, cells) => {
      buf.write_string("    <table>\n")
      let total = cells.length()
      let mut i = 0
      while i < total {
        buf.write_string("      <tr>\n")
        let row_end = if i + cols < total { i + cols } else { total }
        while i < row_end {
          buf.write_string("        <td>")
          render_html_inlines(buf, cells[i])
          buf.write_string("</td>\n")
          i = i + 1
        }
        buf.write_string("      </tr>\n")
      }
      buf.write_string("    </table>\n")
    }
    @core.Block::Shape(shape, style) => {
      let fill_hex = match style.fill {
        Some(c) => c.to_hex()
        None => "none"
      }
      let stroke_hex = match style.stroke {
        Some(c) => c.to_hex()
        None => "none"
      }
      match shape {
        @core.ShapeKind::Rect(w, h, r) => {
          let w_str = w.to_string()
          let h_str = h.to_string()
          buf.write_string(
            "    <div style=\"width: \{w_str}; height: \{h_str}; background: \{fill_hex}; border: \{style.stroke_width}px solid \{stroke_hex}; border-radius: \{r}px; margin: 12px 0;\"></div>\n",
          )
        }
        @core.ShapeKind::Circle(r) => {
          let r_str = r.to_string()
          buf.write_string(
            "    <div style=\"width: calc(\{r_str} * 2); height: calc(\{r_str} * 2); background: \{fill_hex}; border: \{style.stroke_width}px solid \{stroke_hex}; border-radius: 50%; margin: 12px 0;\"></div>\n",
          )
        }
        _ => ()
      }
    }
    @core.Block::Grid(cols, items) => {
      let col_count = if cols.length() > 0 { cols.length() } else { 1 }
      buf.write_string(
        "    <div style=\"display: grid; grid-template-columns: repeat(\{col_count}, 1fr); gap: 16px; margin: 16px 0;\">\n",
      )
      for item in items {
        buf.write_string("      <div>\n")
        render_html_block(buf, item)
        buf.write_string("      </div>\n")
      }
      buf.write_string("    </div>\n")
    }
    @core.Block::FootnoteBlock(idx, inlines) => {
      buf.write_string(
        "    <div class=\"footnote\" id=\"fn-\{idx}\" style=\"font-size: 85%; color: #57606a; margin: 6px 0;\">",
      )
      buf.write_string("<sup>[\{idx}]</sup> ")
      render_html_inlines(buf, inlines)
      buf.write_string("</div>\n")
    }
    @core.Block::Figure(body, caption) => {
      buf.write_string(
        "    <figure style=\"margin: 16px 0; text-align: center;\">\n",
      )
      render_html_block(buf, body)
      match caption {
        Some(inlines) => {
          buf.write_string(
            "      <figcaption style=\"font-size: 85%; color: #57606a; font-style: italic; margin-top: 8px;\">Figure: ",
          )
          render_html_inlines(buf, inlines)
          buf.write_string("</figcaption>\n")
        }
        None => ()
      }
      buf.write_string("    </figure>\n")
    }
    @core.Block::AlignBlock(align, body) => {
      let align_str = match align {
        @core.TextAlign::Center => "center"
        @core.TextAlign::Right => "right"
        @core.TextAlign::Justify => "justify"
        _ => "left"
      }
      buf.write_string("    <div style=\"text-align: \{align_str};\">\n")
      render_html_block(buf, body)
      buf.write_string("    </div>\n")
    }
    @core.Block::HorizontalRule => buf.write_string("    <hr/>\n")
    @core.Block::PageBreak =>
      buf.write_string(
        "    <div style=\"page-break-after: always; height: 1px; border-bottom: 1px dashed #d0d7de; margin: 24px 0;\"></div>\n",
      )
  }
}

///|
fn render_html_inlines(
  buf : StringBuilder,
  inlines : Array[@core.Inline],
) -> Unit {
  for inline in inlines {
    render_single_html_inline(buf, inline)
  }
}

///|
fn render_single_html_inline(
  buf : StringBuilder,
  inline : @core.Inline,
) -> Unit {
  match inline {
    @core.Inline::Text(s) => buf.write_string(escape_xml(s))
    @core.Inline::Bold(inners) => {
      buf.write_string("<strong>")
      render_html_inlines(buf, inners)
      buf.write_string("</strong>")
    }
    @core.Inline::Italic(inners) => {
      buf.write_string("<em>")
      render_html_inlines(buf, inners)
      buf.write_string("</em>")
    }
    @core.Inline::Code(code) => {
      buf.write_string("<code>")
      buf.write_string(escape_xml(code))
      buf.write_string("</code>")
    }
    @core.Inline::InlineMath(expr) => {
      buf.write_string("<span class=\"math-inline\">")
      render_html_math(buf, expr)
      buf.write_string("</span>")
    }
    @core.Inline::Link(url, text) => {
      let display = if text.length() > 0 { text } else { url }
      buf.write_string("<a href=\"\{escape_xml(url)}\">")
      buf.write_string(escape_xml(display))
      buf.write_string("</a>")
    }
    @core.Inline::FootnoteRef(idx) =>
      buf.write_string("<sup><a href=\"#fn-\{idx}\">[\{idx}]</a></sup>")
    @core.Inline::StyledSpan(inners, custom_color, custom_size) => {
      let mut style_str = ""
      match custom_color {
        Some(c) => style_str = style_str + "color: " + c.to_hex() + "; "
        None => ()
      }
      match custom_size {
        Some(s) => style_str = style_str + "font-size: " + s.to_string() + "px; "
        None => ()
      }
      buf.write_string("<span style=\"\{style_str}\">")
      render_html_inlines(buf, inners)
      buf.write_string("</span>")
    }
    @core.Inline::LineBreak => buf.write_string("<br/>")
  }
}

///|
fn render_html_math(buf : StringBuilder, expr : @core.MathExpr) -> Unit {
  match expr {
    @core.MathExpr::Sym(s) => buf.write_string(escape_xml(s))
    @core.MathExpr::Op(op) => {
      buf.write_string(" ")
      buf.write_string(escape_xml(op))
      buf.write_string(" ")
    }
    @core.MathExpr::Frac(num, den) => {
      buf.write_string("<span class=\"frac\"><span class=\"num\">")
      render_html_math(buf, num)
      buf.write_string("</span><span class=\"den\">")
      render_html_math(buf, den)
      buf.write_string("</span></span>")
    }
    @core.MathExpr::Sqrt(inner) => {
      buf.write_string(
        "&radic;<span style=\"border-top: 1px solid #1f2328; padding-top: 1px;\">",
      )
      render_html_math(buf, inner)
      buf.write_string("</span>")
    }
    @core.MathExpr::SubSup(base, sub, sup) => {
      render_html_math(buf, base)
      match sub {
        Some(s) => {
          buf.write_string("<sub>")
          render_html_math(buf, s)
          buf.write_string("</sub>")
        }
        None => ()
      }
      match sup {
        Some(s) => {
          buf.write_string("<sup>")
          render_html_math(buf, s)
          buf.write_string("</sup>")
        }
        None => ()
      }
    }
    @core.MathExpr::Group(items) =>
      for item in items {
        render_html_math(buf, item)
      }
    @core.MathExpr::Matrix(rows, cols, elems) => {
      buf.write_string(
        "<span class=\"matrix-wrapper\" style=\"display: inline-flex; align-items: center; border-left: 2px solid #1f2328; border-right: 2px solid #1f2328; padding: 0 4px; margin: 0 4px;\"><table style=\"border-collapse: collapse; margin: 0;\">",
      )
      for r = 0; r < rows; r = r + 1 {
        buf.write_string("<tr>")
        for c = 0; c < cols; c = c + 1 {
          let idx = r * cols + c
          buf.write_string(
            "<td style=\"border: none; padding: 2px 6px; text-align: center;\">",
          )
          if idx < elems.length() {
            render_html_math(buf, elems[idx])
          }
          buf.write_string("</td>")
        }
        buf.write_string("</tr>")
      }
      buf.write_string("</table></span>")
    }
    @core.MathExpr::Vec(elems) =>
      render_html_math(buf, @core.MathExpr::Matrix(elems.length(), 1, elems))
    @core.MathExpr::Accent(inner, acc) => {
      let sym = match acc {
        "hat" => "^"
        "tilde" => "~"
        "bar" => "&#772;"
        "dot" => "&#775;"
        "vec" => "&#8407;"
        _ => "^"
      }
      buf.write_string(
        "<span style=\"position: relative; display: inline-block;\">",
      )
      render_html_math(buf, inner)
      buf.write_string(
        "<span style=\"position: absolute; top: -0.6em; left: 50%; transform: translateX(-50%); font-size: 0.8em;\">\{sym}</span></span>",
      )
    }
    @core.MathExpr::Limits(op, lower, upper) => {
      buf.write_string(
        "<span style=\"display: inline-flex; flex-direction: column; vertical-align: middle; text-align: center;\">",
      )
      match upper {
        Some(up) => {
          buf.write_string("<span style=\"font-size: 0.7em;\">")
          render_html_math(buf, up)
          buf.write_string("</span>")
        }
        None => ()
      }
      render_html_math(buf, op)
      match lower {
        Some(low) => {
          buf.write_string("<span style=\"font-size: 0.7em;\">")
          render_html_math(buf, low)
          buf.write_string("</span>")
        }
        None => ()
      }
      buf.write_string("</span>")
    }
  }
}
