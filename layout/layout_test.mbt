test "measure_text_width calculation" {
  let w_ascii = measure_text_width("Hello", 16.0)
  assert_eq(w_ascii > 20.0, true)
  assert_eq(w_ascii < 60.0, true)

  let w_cjk = measure_text_width("你好世界", 16.0)
  assert_eq(w_cjk, 64.0) // 4 chars * 16.0
}

test "layout document blocks into box tree" {
  let ctx = @core.StyleContext::default()
  let engine = LayoutEngine::new(ctx)

  let doc = @core.Doc::new()
  doc.add_block(@core.Block::Heading(1, [@core.Inline::Text("Typst in MoonBit")]))
  doc.add_block(@core.Block::Paragraph([@core.Inline::Text("This is a paragraph.")]))
  doc.add_block(@core.Block::CodeBlock("moonbit", "let a = 10\n"))
  doc.add_block(@core.Block::HorizontalRule)

  let page = engine.layout_doc(doc)
  assert_eq(page.width, 800.0)
  assert_eq(page.height >= 1100.0, true)
  assert_eq(page.boxes.length() > 3, true)

  // Verify all boxes are within page bounds
  let all_in_bounds = page.boxes.all(fn(b) {
    b.rect.x >= 0.0 && b.rect.x + b.rect.w <= page.width + 10.0
  })
  assert_eq(all_in_bounds, true)
}
