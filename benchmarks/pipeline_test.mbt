///|
test "document pipeline" (b : @bench.T) {
  let source = "= Sample Report\n\nA compact document with *styled* text and a table.\n\n| Target | Parse | Layout | Total |\n| :--- | ---: | ---: | ---: |\n| Native | 1 | 2 | 3 |\n| Wasm | 4 | 5 | 6 |\n"
  let doc = @parser.parse_typst(source)
  let page = @layout.LayoutEngine::new(@core.StyleContext::default()).layout_doc(
    doc,
  )

  b.bench(name="parse", fn() { b.keep(@parser.parse_typst(source)) })
  b.bench(name="layout", fn() {
    b.keep(
      @layout.LayoutEngine::new(@core.StyleContext::default()).layout_doc(doc),
    )
  })
  b.bench(name="html", fn() { b.keep(@render.render_html(doc)) })
  b.bench(name="svg", fn() { b.keep(@render.render_svg(page)) })
  b.bench(name="pdf", fn() { b.keep(@render.render_pdf(page)) })
}
