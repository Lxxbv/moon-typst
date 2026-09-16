///|
test "render_svg output structure" {
  let boxes : Array[@layout.LayoutBox] = [
    @layout.LayoutBox::new(
      @layout.Rect::new(48.0, 48.0, 200.0, 28.0),
      @layout.BoxKind::Text("Test Document", 28.0, "#000000", "bold"),
    ),
    @layout.LayoutBox::new(
      @layout.Rect::new(48.0, 90.0, 704.0, 1.0),
      @layout.BoxKind::Line(48.0, 90.0, 752.0, 90.0, "#cccccc", 1.0),
    ),
  ]
  let page : @layout.PageLayout = { width: 800.0, height: 1100.0, boxes }
  let svg = render_svg(page)

  assert_eq(svg.has_prefix("<svg xmlns="), true)
  assert_eq(svg.has_suffix("</svg>\n"), true)
  assert_eq(svg.contains("Test Document"), true)
  assert_eq(svg.contains("<line x1=\"48\""), true)
}

///|
test "escape_xml functionality" {
  let raw = "Math: < & > \" '"
  let escaped = escape_xml(raw)
  assert_eq(escaped, "Math: &lt; &amp; &gt; &quot; &apos;")
}

///|
test "render_html output structure" {
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Heading(1, [@core.Inline::Text("Typst HTML Render")]),
  )
  doc.add_block(
    @core.Block::Paragraph([
      @core.Inline::Text("Hello "),
      @core.Inline::Bold([@core.Inline::Text("World")]),
      @core.Inline::Text("!"),
    ]),
  )
  doc.add_block(
    @core.Block::MathBlock(
      @core.MathExpr::Frac(@core.MathExpr::Sym("x"), @core.MathExpr::Sym("y")),
    ),
  )
  doc.add_block(@core.Block::HorizontalRule)

  let html = render_html(doc)
  assert_eq(html.has_prefix("<!DOCTYPE html>"), true)
  assert_eq(html.has_suffix("</html>\n"), true)
  assert_eq(html.contains("<h1>Typst HTML Render</h1>"), true)
  assert_eq(html.contains("<strong>World</strong>"), true)
  assert_eq(html.contains("<div class=\"math-block\">"), true)
  assert_eq(html.contains("<span class=\"frac\">"), true)
  assert_eq(html.contains("<hr/>"), true)
}
