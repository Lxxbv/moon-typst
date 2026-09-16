test "diag span merging and ordering" {
  let p1 = Pos::new(1, 5)
  let p2 = Pos::new(1, 10)
  let p3 = Pos::new(2, 3)

  assert_eq(p1.compare(p2) < 0, true)
  assert_eq(p2.compare(p3) < 0, true)

  let s1 = Span::new(p1, p2)
  let s2 = Span::new(p2, p3)
  let merged = s1.merge(s2)

  assert_eq(merged.start, p1)
  assert_eq(merged.end, p3)
  assert_eq(merged.to_string(), "1:5-2:3")
}

test "diagnostic reporter formats errors with snippets" {
  let src =
    #|= Title
    #|*bold text unclosed
    #|Regular line
  let reporter = DiagnosticReporter::new("test.typ", src)
  let span = Span::new(Pos::new(2, 1), Pos::new(2, 10))
  let diag = Diagnostic::error("unclosed bold delimiter", span)
    .with_code("E001")
    .with_hint("add a matching '*' at the end of the styled phrase")

  reporter.add(diag)
  assert_eq(reporter.has_errors(), true)
  assert_eq(reporter.count_errors(), 1)
  assert_eq(reporter.count_warnings(), 0)

  let formatted = reporter.format_diagnostic(diag, false)
  assert_eq(formatted.contains("error[E001]: unclosed bold delimiter"), true)
  assert_eq(formatted.contains("--> test.typ:2:1"), true)
  assert_eq(formatted.contains("*bold text unclosed"), true)
  assert_eq(formatted.contains("^^^^^^^^^"), true)
  assert_eq(formatted.contains("= hint: add a matching '*'"), true)
}

test "diagnostic reporter warnings and hints" {
  let src = "let x = 1\nlet y = 2"
  let reporter = DiagnosticReporter::new("main.typ", src)
  let span = Span::point(1, 5)
  reporter.add(Diagnostic::warning("unused variable x", span))
  reporter.add(Diagnostic::hint("consider prefixing with underscore", span))

  assert_eq(reporter.has_errors(), false)
  assert_eq(reporter.count_warnings(), 1)
  let all_out = reporter.render_all(false)
  assert_eq(all_out.contains("warning: unused variable x"), true)
  assert_eq(all_out.contains("hint: consider prefixing"), true)
}
