///|
/// High-fidelity SVG vector graphics generator for Typst documents

///|
/// Escape XML special characters
pub fn escape_xml(s : String) -> String {
  let buf = StringBuilder()
  let len = s.length()
  for i = 0; i < len; i = i + 1 {
    let c = s[i].to_int().unsafe_to_char()
    match c {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      '"' => buf.write_string("&quot;")
      '\'' => buf.write_string("&apos;")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Render a PageLayout into standard SVG string
pub fn render_svg(page : @layout.PageLayout) -> String {
  let buf = StringBuilder()
  buf.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{page.width}\" height=\"\{page.height}\" viewBox=\"0 0 \{page.width} \{page.height}\">\n",
  )
  buf.write_string("  <style>\n")
  buf.write_string(
    "    text { font-family: system-ui, -apple-system, sans-serif; }\n",
  )
  buf.write_string(
    "    .mono { font-family: ui-monospace, SFMono-Regular, Consolas, monospace; }\n",
  )
  buf.write_string("  </style>\n")
  buf.write_string(
    "  <rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>\n",
  )

  for b in page.boxes {
    render_svg_box(buf, b)
  }

  buf.write_string("</svg>\n")
  buf.to_string()
}

///|
fn render_svg_box(buf : StringBuilder, b : @layout.LayoutBox) -> Unit {
  match b.kind {
    @layout.BoxKind::Text(text, font_size, color, weight) => {
      let baseline_y = b.rect.y + font_size * 0.85
      let font_class = if weight == "monospace" {
        " class=\"mono\""
      } else {
        ""
      }
      let font_style = if weight == "italic" {
        " font-style=\"italic\""
      } else {
        ""
      }
      let font_w = if weight == "bold" { " font-weight=\"bold\"" } else { "" }
      buf.write_string(
        "  <text x=\"\{b.rect.x}\" y=\"\{baseline_y}\" font-size=\"\{font_size}\" fill=\"\{color}\"\{font_class}\{font_style}\{font_w}>",
      )
      buf.write_string(escape_xml(text))
      buf.write_string("</text>\n")
    }
    @layout.BoxKind::RectFill(w, h, fill, radius) => {
      let rx_attr = if radius > 0.0 { " rx=\"\{radius}\"" } else { "" }
      buf.write_string(
        "  <rect x=\"\{b.rect.x}\" y=\"\{b.rect.y}\" width=\"\{w}\" height=\"\{h}\" fill=\"\{fill}\"\{rx_attr}/>\n",
      )
    }
    @layout.BoxKind::RectStroke(w, h, stroke, stroke_width) =>
      buf.write_string(
        "  <rect x=\"\{b.rect.x}\" y=\"\{b.rect.y}\" width=\"\{w}\" height=\"\{h}\" fill=\"none\" stroke=\"\{stroke}\" stroke-width=\"\{stroke_width}\"/>\n",
      )
    @layout.BoxKind::Line(x1, y1, x2, y2, stroke, stroke_width) =>
      buf.write_string(
        "  <line x1=\"\{x1}\" y1=\"\{y1}\" x2=\"\{x2}\" y2=\"\{y2}\" stroke=\"\{stroke}\" stroke-width=\"\{stroke_width}\"/>\n",
      )
    @layout.BoxKind::Circle(r, fill, stroke, stroke_width) => {
      let cx = b.rect.x + r
      let cy = b.rect.y + r
      let fill_attr = if fill.length() > 0 {
        " fill=\"\{fill}\""
      } else {
        " fill=\"none\""
      }
      let stroke_attr = if stroke.length() > 0 {
        " stroke=\"\{stroke}\" stroke-width=\"\{stroke_width}\""
      } else {
        ""
      }
      buf.write_string(
        "  <circle cx=\"\{cx}\" cy=\"\{cy}\" r=\"\{r}\"\{fill_attr}\{stroke_attr}/>\n",
      )
    }
    @layout.BoxKind::Container(children) =>
      for child in children {
        render_svg_box(buf, child)
      }
  }
}
