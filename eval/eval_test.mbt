///|
test "eval values and conversions" {
  let v_int = Val::Int(42)
  let v_float = Val::Float(3.14)
  let v_str = Val::Str("typst")
  let v_bool = Val::Bool(true)
  let v_len = Val::Length(@core.Length::Pt(12.0))
  let v_col = Val::Color(@core.Color::Named("red"))
  let v_align = Val::Align(@core.TextAlign::Center)

  assert_eq(v_int.as_int(), Some(42))
  assert_eq(v_float.as_double(), Some(3.14))
  assert_eq(v_str.as_str(), Some("typst"))
  assert_eq(v_bool.as_bool(), Some(true))
  assert_eq(v_len.as_length(), Some(@core.Length::Pt(12.0)))
  assert_eq(v_col.as_color(), Some(@core.Color::Named("red")))
  assert_eq(v_align.as_align(), Some(@core.TextAlign::Center))
}

///|
test "eval scopes and variable lookup" {
  let style = @core.StyleContext::default()
  let reporter = @diag.DiagnosticReporter::new("test.typ", "")
  let eval = Evaluator::new(style, reporter)

  eval.set_var("author", Val::Str("Alice"))
  assert_eq(eval.lookup_var("author"), Some(Val::Str("Alice")))

  eval.push_scope()
  eval.set_var("author", Val::Str("Bob"))
  assert_eq(eval.lookup_var("author"), Some(Val::Str("Bob")))

  eval.pop_scope()
  assert_eq(eval.lookup_var("author"), Some(Val::Str("Alice")))
}

///|
test "eval apply set rules for text and page" {
  let style = @core.StyleContext::default()
  let reporter = @diag.DiagnosticReporter::new("test.typ", "")
  let eval = Evaluator::new(style, reporter)

  // #set text(size: 20pt, fill: "red", font: "Georgia")
  eval.apply_set_rule("text", [
    ("size", Val::Length(@core.Length::Pt(20.0))),
    ("fill", Val::Color(@core.Color::Named("red"))),
    ("font", Val::Str("Georgia")),
  ])

  assert_eq(eval.style.font_size, 20.0)
  assert_eq(eval.style.text_color, "#cf222e")
  assert_eq(eval.style.font_family, "Georgia")

  // #set page(columns: 2, gap: 30pt)
  eval.apply_set_rule("page", [
    ("columns", Val::Int(2)),
    ("gap", Val::Length(@core.Length::Pt(30.0))),
  ])

  assert_eq(eval.style.columns, 2)
  assert_eq(eval.style.column_gap, 30.0)
}

///|
test "eval builtins: rect, circle, rgb, luma" {
  let rect_val = eval_builtin("rect", [], [
    ("width", Val::Length(@core.Length::Pt(120.0))),
    ("height", Val::Length(@core.Length::Pt(80.0))),
    ("radius", Val::Float(4.0)),
  ])
  match rect_val {
    Val::BlockContent(@core.Block::Shape(@core.ShapeKind::Rect(w, h, r), _)) => {
      assert_eq(w, @core.Length::Pt(120.0))
      assert_eq(h, @core.Length::Pt(80.0))
      assert_eq(r, 4.0)
    }
    _ => abort("expected rect shape block")
  }

  let circle_val = eval_builtin(
    "circle",
    [Val::Length(@core.Length::Pt(25.0))],
    [],
  )
  match circle_val {
    Val::BlockContent(@core.Block::Shape(@core.ShapeKind::Circle(r), _)) =>
      assert_eq(r, @core.Length::Pt(25.0))
    _ => abort("expected circle shape block")
  }

  let rgb_val = eval_builtin(
    "rgb",
    [Val::Int(10), Val::Int(20), Val::Int(30)],
    [],
  )
  assert_eq(rgb_val.as_color(), Some(@core.Color::Rgb(10, 20, 30, 1.0)))

  let luma_val = eval_builtin("luma", [Val::Int(200)], [])
  assert_eq(luma_val.as_color(), Some(@core.Color::Luma(200)))
}
