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

test "escape_xml functionality" {
  let raw = "Math: < & > \" '"
  let escaped = escape_xml(raw)
  assert_eq(escaped, "Math: &lt; &amp; &gt; &quot; &apos;")
}
