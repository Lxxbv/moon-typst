///|
test "doc construction and block manipulation" {
  let doc = Doc::new()
  assert_eq(doc.blocks.length(), 0)

  let heading = Block::Heading(1, [Inline::Text("Introduction")])
  doc.add_block(heading)
  assert_eq(doc.blocks.length(), 1)

  let para = Block::Paragraph([
    Inline::Text("This is "),
    Inline::Bold([Inline::Text("bold")]),
    Inline::Text(" and "),
    Inline::Italic([Inline::Text("italic")]),
    Inline::Text("."),
  ])
  doc.add_block(para)
  assert_eq(doc.blocks.length(), 2)
}

///|
test "math expression AST" {
  let frac = MathExpr::Frac(MathExpr::Sym("a"), MathExpr::Sym("b"))
  let subsup = MathExpr::SubSup(
    MathExpr::Sym("x"),
    None,
    Some(MathExpr::Sym("2")),
  )
  let expr = MathExpr::Group([frac, MathExpr::Op("+"), subsup])
  let block = Block::MathBlock(expr)
  match block {
    Block::MathBlock(MathExpr::Group(items)) => assert_eq(items.length(), 3)
    _ => abort("expected MathBlock with Group")
  }
}

///|
test "style context calculations" {
  let ctx = StyleContext::default()
  assert_eq(ctx.page_width, 800.0)
  assert_eq(ctx.margin_x, 48.0)
  assert_eq(ctx.content_width(), 704.0)
}
