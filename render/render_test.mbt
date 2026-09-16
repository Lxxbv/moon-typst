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
  let page : @layout.PageLayout = { width: 800.0, height: 1100.0, boxes, }
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

///|
test "escape_pdf_string special chars" {
  let raw = "Hello (World) \\ Special \r\n"
  let escaped = escape_pdf_string(raw)
  assert_eq(escaped, "Hello \\(World\\) \\\\ Special \\r\\n")
}

///|
test "render_pdf output structure" {
  let boxes : Array[@layout.LayoutBox] = [
    @layout.LayoutBox::new(
      @layout.Rect::new(50.0, 50.0, 300.0, 24.0),
      @layout.BoxKind::Text("PDF Title", 24.0, "#1a1a1a", "bold"),
    ),
    @layout.LayoutBox::new(
      @layout.Rect::new(50.0, 90.0, 400.0, 100.0),
      @layout.BoxKind::RectFill(400.0, 100.0, "#f0f4f8", 4.0),
    ),
    @layout.LayoutBox::new(
      @layout.Rect::new(50.0, 200.0, 400.0, 2.0),
      @layout.BoxKind::Line(50.0, 200.0, 450.0, 200.0, "#0066cc", 2.0),
    ),
    @layout.LayoutBox::new(
      @layout.Rect::new(60.0, 220.0, 40.0, 40.0),
      @layout.BoxKind::Circle(20.0, "#ff0000", "#333333", 1.5),
    ),
  ]
  let page : @layout.PageLayout = { width: 595.0, height: 842.0, boxes, }
  let pdf = render_pdf(page)

  assert_eq(pdf.has_prefix("%PDF-1.4"), true)
  assert_eq(pdf.contains("/Type /Catalog"), true)
  assert_eq(pdf.contains("/Type /Pages"), true)
  assert_eq(pdf.contains("/Type /Font"), true)
  assert_eq(pdf.contains("/Helvetica-Bold"), true)
  assert_eq(pdf.contains("(PDF Title) Tj"), true)
  assert_eq(pdf.contains("xref"), true)
  assert_eq(pdf.contains("trailer"), true)
  assert_eq(pdf.contains("%%EOF"), true)
}

///|
test "render_pdf_document multi-page structure" {
  let page1 : @layout.PageLayout = {
    width: 595.0,
    height: 842.0,
    boxes: [
      @layout.LayoutBox::new(
        @layout.Rect::new(50.0, 50.0, 200.0, 20.0),
        @layout.BoxKind::Text("Page One Content", 14.0, "#000000", "normal"),
      ),
    ],
  }
  let page2 : @layout.PageLayout = {
    width: 595.0,
    height: 842.0,
    boxes: [
      @layout.LayoutBox::new(
        @layout.Rect::new(50.0, 50.0, 200.0, 20.0),
        @layout.BoxKind::Text("Page Two Content", 14.0, "#000000", "normal"),
      ),
    ],
  }
  let doc : @layout.DocumentLayout = { pages: [page1, page2], }
  let pdf = render_pdf_document(doc)

  assert_eq(pdf.has_prefix("%PDF-1.4"), true)
  assert_eq(pdf.contains("/Count 2"), true)
  assert_eq(pdf.contains("(Page One Content) Tj"), true)
  assert_eq(pdf.contains("(Page Two Content) Tj"), true)
  assert_eq(pdf.contains("%%EOF"), true)
}
