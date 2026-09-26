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
test "render_html table preserves four columns and semantic header" {
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Table({
      rows: [
        [
          [@core.Inline::Text("Target")],
          [@core.Inline::Text("Parse")],
          [@core.Inline::Text("Layout")],
          [@core.Inline::Text("Total")],
        ],
        [
          [@core.Inline::Text("Native")],
          [@core.Inline::Text("0.32")],
          [@core.Inline::Text("0.48")],
          [@core.Inline::Text("0.80")],
        ],
      ],
      header_rows: 1,
      alignments: [
        @core.TableAlignment::Left,
        @core.TableAlignment::Center,
        @core.TableAlignment::Right,
        @core.TableAlignment::Left,
      ],
    }),
  )
  let html = render_html(doc)
  assert_eq(html.contains("<thead>"), true)
  assert_eq(html.contains("</thead>"), true)
  assert_eq(html.contains("<tbody>"), true)
  assert_eq(html.contains("</tbody>"), true)
  assert_eq(html.contains("<th style=\"text-align: left;\">Target</th>"), true)
  assert_eq(html.contains("<th style=\"text-align: center;\">Parse</th>"), true)
  assert_eq(html.contains("<th style=\"text-align: right;\">Layout</th>"), true)
  assert_eq(html.contains("<th style=\"text-align: left;\">Total</th>"), true)
  assert_eq(html.contains("<td style=\"text-align: left;\">Native</td>"), true)
  assert_eq(html.contains("<td style=\"text-align: center;\">0.32</td>"), true)
  assert_eq(html.contains("<td style=\"text-align: right;\">0.48</td>"), true)
  assert_eq(html.contains("<td style=\"text-align: left;\">0.80</td>"), true)
}

///|
test "render_html body-only table retains inline escaping" {
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Table({
      rows: [
        [
          [@core.Inline::Bold([@core.Inline::Text("A&B")])],
          [@core.Inline::Text("<next>")],
        ],
      ],
      header_rows: 0,
      alignments: [@core.TableAlignment::Left, @core.TableAlignment::Right],
    }),
  )
  let html = render_html(doc)
  assert_eq(html.contains("<thead>"), false)
  assert_eq(html.contains("<th"), false)
  assert_eq(html.contains("<tbody>"), true)
  assert_eq(
    html.contains(
      "<td style=\"text-align: left;\"><strong>A&amp;B</strong></td>",
    ),
    true,
  )
  assert_eq(
    html.contains("<td style=\"text-align: right;\">&lt;next&gt;</td>"),
    true,
  )
}

///|
test "table layout geometry serializes in SVG and PDF" {
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Table({
      rows: [
        [
          [@core.Inline::Text("Target")],
          [@core.Inline::Text("Parse")],
          [@core.Inline::Text("Layout")],
          [@core.Inline::Text("Total")],
        ],
        [
          [@core.Inline::Text("Native")],
          [@core.Inline::Text("0.32")],
          [@core.Inline::Text("0.48")],
          [@core.Inline::Text("0.80")],
        ],
      ],
      header_rows: 1,
      alignments: [
        @core.TableAlignment::Left,
        @core.TableAlignment::Center,
        @core.TableAlignment::Right,
        @core.TableAlignment::Left,
      ],
    }),
  )
  let page = @layout.LayoutEngine::new(@core.StyleContext::default()).layout_doc(
    doc,
  )
  let svg = render_svg(page)
  let pdf = render_pdf(page)
  let mut text_count = 0
  let mut border_count = 0
  let mut bold_count = 0
  for box in page.boxes {
    match box.kind {
      @layout.BoxKind::Text(label, _, _, weight) => {
        text_count = text_count + 1
        assert_eq(svg.contains(">\{escape_xml(label)}</text>"), true)
        assert_eq(pdf.contains("(\{escape_pdf_string(label)}) Tj"), true)
        if weight == "bold" {
          bold_count = bold_count + 1
          assert_eq(
            svg.contains("font-weight=\"bold\">\{escape_xml(label)}</text>"),
            true,
          )
        }
      }
      @layout.BoxKind::RectStroke(w, h, _, _) => {
        border_count = border_count + 1
        let pdf_y = page.height - box.rect.y - h
        assert_eq(
          svg.contains(
            "<rect x=\"\{box.rect.x}\" y=\"\{box.rect.y}\" width=\"\{w}\" height=\"\{h}\" fill=\"none\"",
          ),
          true,
        )
        assert_eq(pdf.contains("\{box.rect.x} \{pdf_y} \{w} \{h} re s"), true)
      }
      _ => ()
    }
  }
  assert_eq(text_count, 8)
  assert_eq(border_count, 8)
  assert_eq(bold_count, 4)
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
