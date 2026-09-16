test "ast construction and basic doc structure" {
  let doc = Doc::new()
  doc.add_block(
    Block::Heading(1, [
      Inline::Text("Hello"),
      Inline::Bold([Inline::Text("Typst")]),
    ]),
  )
  doc.add_block(
    Block::Paragraph([
      Inline::Text("A simple formula: "),
      Inline::InlineMath(
        MathExpr::Frac(MathExpr::Sym("a"), MathExpr::Sym("b")),
      ),
    ]),
  )

  assert_eq(doc.blocks.length(), 2)

  let ctx = StyleContext::default()
  assert_eq(ctx.content_width(), 704.0)
  assert_eq(ctx.column_width(), 704.0)
}

test "core length conversion to points" {
  let pt_len = Length::Pt(10.0)
  let mm_len = Length::Mm(25.4)
  let em_len = Length::Em(1.5)
  let pct_len = Length::Percent(50.0)

  assert_eq(pt_len.to_pt(16.0, 700.0), 10.0)
  assert_eq(mm_len.to_pt(16.0, 700.0), 72.0)
  assert_eq(em_len.to_pt(16.0, 700.0), 24.0)
  assert_eq(pct_len.to_pt(16.0, 700.0), 350.0)
}

test "core color formatting and normalization" {
  let c1 = Color::Rgb(255, 0, 128, 1.0)
  assert_eq(c1.to_hex(), "#ff0080")
  let (r, g, b, a) = c1.to_normalized()
  assert_eq(r, 1.0)
  assert_eq(g, 0.0)
  assert_eq(b > 0.5, true)
  assert_eq(a, 1.0)

  let c2 = Color::Named("blue")
  assert_eq(c2.to_hex(), "#0969da")

  let c3 = Color::Luma(128)
  assert_eq(c3.to_hex(), "#808080")
}

test "core advanced math and shape ast nodes" {
  let matrix = MathExpr::Matrix(2, 2, [
    MathExpr::Sym("1"),
    MathExpr::Sym("0"),
    MathExpr::Sym("0"),
    MathExpr::Sym("1"),
  ])
  let vec_expr = MathExpr::Vec([MathExpr::Sym("x"), MathExpr::Sym("y")])
  let accent = MathExpr::Accent(MathExpr::Sym("x"), "hat")
  let limits = MathExpr::Limits(
    MathExpr::Sym("sum"),
    Some(MathExpr::Sym("i=1")),
    Some(MathExpr::Sym("n")),
  )

  let rect_shape = Block::Shape(
    ShapeKind::Rect(Length::Pt(100.0), Length::Pt(50.0), 4.0),
    ShapeStyle::default(),
  )
  let grid_block = Block::Grid(
    [Length::Fr(1.0), Length::Fr(2.0)],
    [rect_shape, Block::Paragraph([Inline::Text("Cell 2")])],
  )

  let doc = Doc::new()
  doc.add_block(Block::MathBlock(matrix))
  doc.add_block(Block::MathBlock(vec_expr))
  doc.add_block(Block::MathBlock(accent))
  doc.add_block(Block::MathBlock(limits))
  doc.add_block(grid_block)

  assert_eq(doc.blocks.length(), 5)
}

test "core multi-column layout width calculation" {
  let ctx : StyleContext = {
    page_width: 800.0,
    page_height: 1100.0,
    margin_x: 50.0,
    margin_y: 50.0,
    font_size: 14.0,
    line_height: 1.4,
    text_color: "#000000",
    bg_color: "#ffffff",
    code_bg_color: "#f0f0f0",
    font_family: "sans-serif",
    columns: 2,
    column_gap: 20.0,
    text_align: TextAlign::Justify,
    header: None,
    footer: None,
  }

  // content_width = 800 - 100 = 700
  // columns = 2, gap = 20, col_width = (700 - 20) / 2 = 340
  assert_eq(ctx.content_width(), 700.0)
  assert_eq(ctx.column_width(), 340.0)
}
