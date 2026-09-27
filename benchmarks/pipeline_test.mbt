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

///|
fn compile_to_html(source : String) -> String {
  let reporter = @diag.DiagnosticReporter::new("benchmark.typ", source)
  let evaluator = @eval.Evaluator::new(@core.StyleContext::default(), reporter)
  let doc = @parser.parse_typst(source)
  ignore(evaluator)
  @render.render_html(doc)
}

///|
fn compile_to_svg(source : String) -> String {
  let reporter = @diag.DiagnosticReporter::new("benchmark.typ", source)
  let evaluator = @eval.Evaluator::new(@core.StyleContext::default(), reporter)
  let doc = @parser.parse_typst(source)
  let page = @layout.LayoutEngine::new(evaluator.style).layout_doc(doc)
  @render.render_svg(page)
}

///|
fn compile_to_pdf(source : String) -> String {
  let reporter = @diag.DiagnosticReporter::new("benchmark.typ", source)
  let evaluator = @eval.Evaluator::new(@core.StyleContext::default(), reporter)
  let doc = @parser.parse_typst(source)
  let page = @layout.LayoutEngine::new(evaluator.style).layout_doc(doc)
  @render.render_pdf(page)
}

///|
test "end-to-end in-memory compilation" (b : @bench.T) {
  let source = "= MoonBit 中文 PDF 示例\n\nmoon-typst 是一个用 MoonBit 实现的 Typst 风格标记语言子集排版工具，包含词法分析、递归下降解析、文本与数学表达式处理、盒模型布局，以及 HTML、SVG 和 PDF 多种输出。这个段落刻意包含足够长的连续中文文本，用来覆盖实际文档中的自动换行路径；同时混排 *格式文本*、拉丁重音字符 café、数字 2026 和英文 API 名称，检查不同字符宽度与空格处理。\n\n项目使用固定的页面尺寸与边距，布局阶段逐行生成文本盒和表格单元格，再交给渲染器序列化为目标格式。基准把诊断器与样式上下文初始化、源码解析、排版和目标渲染放在同一计时区间，使用相同源码比较三个后端。\n\n| 后端 | 输出内容 | 测量范围 |\n| :--- | :--- | :--- |\n| PDF | 中文文本与矢量图形 | 解析、排版、PDF 序列化 |\n| SVG | Unicode 文本与矢量图形 | 解析、排版、SVG 序列化 |\n| HTML | 语义化文档结构 | 解析、HTML 序列化 |\n"

  b.bench(name="e2e_html", fn() { b.keep(compile_to_html(source)) })
  b.bench(name="e2e_svg", fn() { b.keep(compile_to_svg(source)) })
  b.bench(name="e2e_pdf", fn() { b.keep(compile_to_pdf(source)) })
}
