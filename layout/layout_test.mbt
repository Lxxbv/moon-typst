///|
test "measure_text_width calculation" {
  let w_ascii = measure_text_width("Hello", 16.0)
  assert_eq(w_ascii > 20.0, true)
  assert_eq(w_ascii < 60.0, true)

  let w_cjk = measure_text_width("你好世界", 16.0)
  assert_eq(w_cjk, 64.0) // 4 chars * 16.0
}

///|
test "layout document blocks into box tree" {
  let ctx = @core.StyleContext::default()
  let engine = LayoutEngine::new(ctx)

  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Heading(1, [@core.Inline::Text("Typst in MoonBit")]),
  )
  doc.add_block(
    @core.Block::Paragraph([@core.Inline::Text("This is a paragraph.")]),
  )
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

///|
test "wrap long CJK paragraph text within the page content width" {
  let ctx = @core.StyleContext::default()
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Paragraph([
      @core.Inline::Text(
        "这是一段用于验证中文自然折行的长文本，字符之间没有空格，排版引擎也应该逐字换行，不能让文字越过页面右边界。",
      ),
    ]),
  )
  let page = LayoutEngine::new(ctx).layout_doc(doc)
  let max_x = ctx.page_width - ctx.margin_x
  let mut first_line_y = -1.0
  let mut found_next_line = false
  for box in page.boxes {
    match box.kind {
      BoxKind::Text(_, _, _, _) => {
        assert_eq(box.rect.x + box.rect.w <= max_x + 0.01, true)
        if first_line_y < 0.0 {
          first_line_y = box.rect.y
        } else if box.rect.y > first_line_y {
          found_next_line = true
        }
      }
      _ => ()
    }
  }
  assert_eq(found_next_line, true)
}

///|
test "measure and preserve supplementary text while laying out a paragraph" {
  assert_eq(measure_text_width("😀", 16.0), 16.0)
  let doc = @core.Doc::new()
  doc.add_block(@core.Block::Paragraph([@core.Inline::Text("A😀B")]))
  let page = LayoutEngine::new(@core.StyleContext::default()).layout_doc(doc)
  let text = StringBuilder()
  for box in page.boxes {
    match box.kind {
      BoxKind::Text(value, _, _, _) => text.write_string(value)
      _ => ()
    }
  }
  assert_eq(text.to_string(), "A😀B")
}

///|
test "wrap Latin paragraph words and oversized tokens within page bounds" {
  let ctx = @core.StyleContext::default()
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Paragraph([
      @core.Inline::Text(
        "This paragraph contains enough words to wrap naturally at spaces, followed by an unusuallylongidentifierthatmuststillstayinsidethepageboundary.",
      ),
    ]),
  )
  let page = LayoutEngine::new(ctx).layout_doc(doc)
  let max_x = ctx.page_width - ctx.margin_x
  let mut found_next_line = false
  let mut first_line_y = -1.0
  for box in page.boxes {
    match box.kind {
      BoxKind::Text(_, _, _, _) => {
        assert_eq(box.rect.x + box.rect.w <= max_x + 0.01, true)
        if first_line_y < 0.0 {
          first_line_y = box.rect.y
        } else if box.rect.y > first_line_y {
          found_next_line = true
        }
      }
      _ => ()
    }
  }
  assert_eq(found_next_line, true)
}

///|
test "table columns are equal and wrapped rows contain their text" {
  let ctx = @core.StyleContext::default()
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Table({
      rows: [
        [
          [
            @core.Inline::Text(
              "many small words must wrap inside this narrow first cell",
            ),
          ],
          [@core.Inline::Text("short")],
        ],
        [[@core.Inline::Text("next")], [@core.Inline::Text("row")]],
      ],
      header_rows: 0,
      alignments: [@core.TableAlignment::Left, @core.TableAlignment::Left],
    }),
  )
  let page = LayoutEngine::new(ctx).layout_doc(doc)
  let borders : Array[Rect] = []
  let texts : Array[LayoutBox] = []
  for box in page.boxes {
    match box.kind {
      BoxKind::RectStroke(_, _, _, _) => borders.push(box.rect)
      BoxKind::Text(_, _, _, _) => texts.push(box)
      _ => ()
    }
  }
  assert_eq(borders.length(), 4)
  assert_eq(borders[0].w, borders[1].w)
  assert_eq(borders[0].x + borders[0].w, borders[1].x)
  assert_eq(borders[0].h > ctx.font_size * 2.2, true)
  assert_eq(borders[2].y, borders[0].y + borders[0].h)
  assert_eq(borders[3].y, borders[2].y)
  for box in texts {
    match box.kind {
      BoxKind::Text(text, _, _, _) => {
        let cell = if text == "short" {
          borders[1]
        } else if text == "next" {
          borders[2]
        } else if text == "row" {
          borders[3]
        } else {
          borders[0]
        }
        let rect = box.rect
        assert_eq(rect.x >= cell.x + 8.0, true)
        assert_eq(rect.x + rect.w <= cell.x + cell.w - 8.0, true)
        assert_eq(rect.y >= cell.y + 8.0, true)
        assert_eq(rect.y + rect.h <= cell.y + cell.h - 8.0, true)
      }
      _ => ()
    }
  }
  assert_eq(texts.length() > 4, true)
}

///|
test "table header emphasis and column alignment use text geometry" {
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Table({
      rows: [
        [
          [@core.Inline::Text("L")],
          [@core.Inline::Text("C")],
          [@core.Inline::Text("R")],
        ],
        [
          [@core.Inline::Text("body")],
          [@core.Inline::Text("body")],
          [@core.Inline::Text("body")],
        ],
      ],
      header_rows: 1,
      alignments: [
        @core.TableAlignment::Left,
        @core.TableAlignment::Center,
        @core.TableAlignment::Right,
      ],
    }),
  )
  let page = LayoutEngine::new(@core.StyleContext::default()).layout_doc(doc)
  let borders : Array[Rect] = []
  let headers : Array[LayoutBox] = []
  let mut body_normal = true
  for box in page.boxes {
    match box.kind {
      BoxKind::RectStroke(_, _, _, _) => borders.push(box.rect)
      BoxKind::Text(text, _, _, weight) =>
        if text == "L" || text == "C" || text == "R" {
          headers.push(box)
          assert_eq(weight, "bold")
        } else if text == "body" && weight != "normal" {
          body_normal = false
        }
      _ => ()
    }
  }
  assert_eq(headers.length(), 3)
  assert_eq(body_normal, true)
  assert_eq(headers[0].rect.x, borders[0].x + 8.0)
  let centered = borders[1].x + (borders[1].w - headers[1].rect.w) / 2.0
  assert_eq(
    headers[1].rect.x - centered < 0.001 && centered - headers[1].rect.x < 0.001,
    true,
  )
  let right_edge = borders[2].x + borders[2].w - 8.0
  let text_right = headers[2].rect.x + headers[2].rect.w
  assert_eq(
    text_right - right_edge < 0.001 && right_edge - text_right < 0.001,
    true,
  )
}

///|
test "table inline math text stays within its cell" {
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Table({
      rows: [
        [
          [
            @core.Inline::InlineMath(
              @core.MathExpr::Sym(
                "thisverylongmathematicalsymbolmustwrapacrossmultiplelinesinsideitscell",
              ),
            ),
          ],
          [@core.Inline::Text("neighbor")],
        ],
      ],
      header_rows: 0,
      alignments: [@core.TableAlignment::Left, @core.TableAlignment::Left],
    }),
  )
  let page = LayoutEngine::new(@core.StyleContext::default()).layout_doc(doc)
  let borders : Array[Rect] = []
  let texts : Array[Rect] = []
  for box in page.boxes {
    match box.kind {
      BoxKind::RectStroke(_, _, _, _) => borders.push(box.rect)
      BoxKind::Text(_, _, _, _) => texts.push(box.rect)
      _ => ()
    }
  }
  assert_eq(texts.length() > 2, true)
  for rect in texts {
    let mut inside = false
    for cell in borders {
      if rect.x >= cell.x + 8.0 &&
        rect.x + rect.w <= cell.x + cell.w - 8.0 &&
        rect.y >= cell.y + 8.0 &&
        rect.y + rect.h <= cell.y + cell.h - 8.0 {
        inside = true
      }
    }
    assert_eq(inside, true)
  }
}

///|
test "oversized table glyph fits the padded cell width" {
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Table({
      rows: [
        [
          [
            @core.Inline::StyledSpan(
              [@core.Inline::Text("W")],
              None,
              Some(500.0),
            ),
          ],
          [@core.Inline::Text("other")],
        ],
      ],
      header_rows: 0,
      alignments: [@core.TableAlignment::Left, @core.TableAlignment::Left],
    }),
  )
  let page = LayoutEngine::new(@core.StyleContext::default()).layout_doc(doc)
  let mut cell = Rect::new(0.0, 0.0, 0.0, 0.0)
  let mut glyph = Rect::new(0.0, 0.0, 0.0, 0.0)
  for box in page.boxes {
    match box.kind {
      BoxKind::RectStroke(_, _, _, _) => if cell.w == 0.0 { cell = box.rect }
      BoxKind::Text(text, _, _, _) => if text == "W" { glyph = box.rect }
      _ => ()
    }
  }
  assert_eq(glyph.w > 0.0, true)
  assert_eq(glyph.x + glyph.w <= cell.x + cell.w - 8.0, true)
}

///|
test "fitting table fraction retains numerator bar and denominator" {
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Table({
      rows: [
        [
          [
            @core.Inline::InlineMath(
              @core.MathExpr::Frac(
                @core.MathExpr::Sym("a"),
                @core.MathExpr::Sym("b"),
              ),
            ),
          ],
          [@core.Inline::Text("neighbor")],
        ],
      ],
      header_rows: 0,
      alignments: [@core.TableAlignment::Left, @core.TableAlignment::Left],
    }),
  )
  let page = LayoutEngine::new(@core.StyleContext::default()).layout_doc(doc)
  let mut cell = Rect::new(0.0, 0.0, 0.0, 0.0)
  let mut numerator = Rect::new(0.0, 0.0, 0.0, 0.0)
  let mut denominator = Rect::new(0.0, 0.0, 0.0, 0.0)
  let mut bar = Rect::new(0.0, 0.0, 0.0, 0.0)
  for box in page.boxes {
    match box.kind {
      BoxKind::RectStroke(_, _, _, _) => if cell.w == 0.0 { cell = box.rect }
      BoxKind::Line(_, _, _, _, _, _) => bar = box.rect
      BoxKind::Text(text, _, _, _) => {
        if text == "a" {
          numerator = box.rect
        }
        if text == "b" {
          denominator = box.rect
        }
      }
      _ => ()
    }
  }
  assert_eq(bar.w > 0.0, true)
  assert_eq(numerator.y < bar.y && bar.y < denominator.y, true)
  assert_eq(numerator.y >= cell.y + 8.0, true)
  assert_eq(denominator.y + denominator.h <= cell.y + cell.h - 8.0, true)
  assert_eq(
    bar.x >= cell.x + 8.0 && bar.x + bar.w <= cell.x + cell.w - 8.0,
    true,
  )
}

///|
test "table wrap follows tall glyph without changing neighboring cell flow" {
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Table({
      rows: [
        [
          [
            @core.Inline::StyledSpan(
              [@core.Inline::Text("W")],
              None,
              Some(80.0),
            ),
            @core.Inline::Text("mmmmmmmmmmmmmmmmmmmmmmmm"),
          ],
          [@core.Inline::Text("neighbor")],
        ],
        [[@core.Inline::Text("next")], [@core.Inline::Text("row")]],
      ],
      header_rows: 0,
      alignments: [@core.TableAlignment::Left, @core.TableAlignment::Left],
    }),
  )
  let page = LayoutEngine::new(@core.StyleContext::default()).layout_doc(doc)
  let borders : Array[Rect] = []
  let mut tall = Rect::new(0.0, 0.0, 0.0, 0.0)
  let mut after = tall
  let mut neighbor = tall
  for box in page.boxes {
    match box.kind {
      BoxKind::RectStroke(_, _, _, _) => borders.push(box.rect)
      BoxKind::Text(text, _, _, _) => {
        if text == "W" {
          tall = box.rect
        }
        if text == "mmmmmmmmmmmmmmmmmmmmmmmm" {
          after = box.rect
        }
        if text == "neighbor" {
          neighbor = box.rect
        }
      }
      _ => ()
    }
  }
  assert_eq(tall.h > 0.0 && after.h > 0.0 && neighbor.h > 0.0, true)
  assert_eq(after.y >= tall.y + tall.h, true)
  assert_eq(neighbor.y < after.y, true)
  assert_eq(after.y + after.h <= borders[0].y + borders[0].h - 8.0, true)
  assert_eq(borders[2].y, borders[0].y + borders[0].h)
}

///|
test "table line break follows full matrix height" {
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Table({
      rows: [
        [
          [
            @core.Inline::InlineMath(
              @core.MathExpr::Matrix(2, 2, [
                @core.MathExpr::Sym("a"),
                @core.MathExpr::Sym("b"),
                @core.MathExpr::Sym("c"),
                @core.MathExpr::Sym("d"),
              ]),
            ),
            @core.Inline::LineBreak,
            @core.Inline::Text("after"),
          ],
          [@core.Inline::Text("neighbor")],
        ],
      ],
      header_rows: 0,
      alignments: [@core.TableAlignment::Left, @core.TableAlignment::Left],
    }),
  )
  let page = LayoutEngine::new(@core.StyleContext::default()).layout_doc(doc)
  let mut math_bottom = 0.0
  let mut after = Rect::new(0.0, 0.0, 0.0, 0.0)
  for box in page.boxes {
    match box.kind {
      BoxKind::Line(_, _, _, _, _, _) =>
        if box.rect.y + box.rect.h > math_bottom {
          math_bottom = box.rect.y + box.rect.h
        }
      BoxKind::Text(text, _, _, _) => {
        if text == "a" || text == "b" || text == "c" || text == "d" {
          if box.rect.y + box.rect.h > math_bottom {
            math_bottom = box.rect.y + box.rect.h
          }
        }
        if text == "after" {
          after = box.rect
        }
      }
      _ => ()
    }
  }
  assert_eq(math_bottom > 0.0 && after.h > 0.0, true)
  assert_eq(after.y >= math_bottom, true)
}

///|
test "overwide matrix fallback retains rows unlike vector fallback" {
  let values = [
    @core.MathExpr::Sym("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
    @core.MathExpr::Sym("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
    @core.MathExpr::Sym("cccccccccccccccccccccccccccccccccccccccccccccccccc"),
    @core.MathExpr::Sym("dddddddddddddddddddddddddddddddddddddddddddddddddd"),
  ]
  let matrix = @core.MathExpr::Matrix(2, 2, values)
  let vector = @core.MathExpr::Vec(values)
  let ctx = @core.StyleContext::default()
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Table({
      rows: [
        [[@core.Inline::InlineMath(matrix)], [@core.Inline::InlineMath(vector)]],
      ],
      header_rows: 0,
      alignments: [@core.TableAlignment::Left, @core.TableAlignment::Left],
    }),
  )
  let page = LayoutEngine::new(ctx).layout_doc(doc)
  let split_x = ctx.margin_x + ctx.content_width() / 2.0
  let matrix_builder = StringBuilder()
  let vector_builder = StringBuilder()
  for box in page.boxes {
    match box.kind {
      BoxKind::Text(text, _, _, _) =>
        if box.rect.x < split_x {
          matrix_builder.write_string(text)
        } else {
          vector_builder.write_string(text)
        }
      _ => ()
    }
  }
  let matrix_text = matrix_builder.to_string()
  let vector_text = vector_builder.to_string()
  assert_eq(matrix_text.contains("matrix(2x2:"), true)
  assert_eq(matrix_text != vector_text, true)
  assert_eq(matrix_text.contains("], ["), true)
  assert_eq(vector_text.contains("], ["), false)
}

///|
test "preserve whitespace at styled inline boundaries" {
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Paragraph([
      @core.Inline::Text("left "),
      @core.Inline::Bold([@core.Inline::Text("bold")]),
    ]),
  )
  let page = LayoutEngine::new(@core.StyleContext::default()).layout_doc(doc)
  let mut left = Rect::new(0.0, 0.0, 0.0, 0.0)
  let mut bold = Rect::new(0.0, 0.0, 0.0, 0.0)
  for box in page.boxes {
    match box.kind {
      BoxKind::Text(text, _, _, _) =>
        if text == "left" {
          left = box.rect
        } else if text == "bold" {
          bold = box.rect
        }
      _ => ()
    }
  }
  assert_eq(left.w > 0.0 && bold.w > 0.0, true)
  assert_eq(bold.x > left.x + left.w, true)
}

///|
test "wrap inline links, math, and footnote refs after trailing spaces" {
  let prefix = StringBuilder()
  for _ in 0..<79 {
    prefix.write_char('a')
  }
  let text = prefix.to_string() + " "
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Paragraph([
      @core.Inline::Text(text),
      @core.Inline::Link("https://example.com", "link"),
    ]),
  )
  doc.add_block(
    @core.Block::Paragraph([
      @core.Inline::Text(text),
      @core.Inline::InlineMath(@core.MathExpr::Sym("x")),
    ]),
  )
  doc.add_block(
    @core.Block::Paragraph([
      @core.Inline::Text(text),
      @core.Inline::FootnoteRef(1),
    ]),
  )

  let ctx = @core.StyleContext::default()
  let page = LayoutEngine::new(ctx).layout_doc(doc)
  let max_x = ctx.page_width - ctx.margin_x
  for box in page.boxes {
    match box.kind {
      BoxKind::Text(_, _, _, _) =>
        assert_eq(box.rect.x + box.rect.w <= max_x + 0.01, true)
      _ => ()
    }
  }
}

///|
test "wrap limits using the widest rendered bound" {
  let prefix = StringBuilder()
  for _ in 0..<77 {
    prefix.write_char('a')
  }
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Paragraph([
      @core.Inline::Text(prefix.to_string() + " "),
      @core.Inline::InlineMath(
        @core.MathExpr::Limits(
          @core.MathExpr::Sym("∑"),
          None,
          Some(@core.MathExpr::Sym("abcde")),
        ),
      ),
    ]),
  )

  let ctx = @core.StyleContext::default()
  let page = LayoutEngine::new(ctx).layout_doc(doc)
  let max_x = ctx.page_width - ctx.margin_x
  for box in page.boxes {
    match box.kind {
      BoxKind::Text(_, _, _, _) =>
        assert_eq(box.rect.x + box.rect.w <= max_x + 0.01, true)
      _ => ()
    }
  }
}

///|
test "wrap accent using the mark's rendered width" {
  let prefix = StringBuilder()
  for _ in 0..<76 {
    prefix.write_char('a')
  }
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Paragraph([
      @core.Inline::StyledSpan(
        [@core.Inline::Text(prefix.to_string())],
        None,
        Some(16.6076555),
      ),
      @core.Inline::InlineMath(
        @core.MathExpr::Accent(@core.MathExpr::Sym("x"), "hat"),
      ),
    ]),
  )

  let ctx = @core.StyleContext::default()
  let page = LayoutEngine::new(ctx).layout_doc(doc)
  let max_x = ctx.page_width - ctx.margin_x
  for box in page.boxes {
    match box.kind {
      BoxKind::Text(_, _, _, _) =>
        assert_eq(box.rect.x + box.rect.w <= max_x + 0.01, true)
      _ => ()
    }
  }
}

///|
test "wrap lower formula limit using its rendered width" {
  let prefix = StringBuilder()
  for _ in 0..<77 {
    prefix.write_char('a')
  }
  let doc = @core.Doc::new()
  doc.add_block(
    @core.Block::Paragraph([
      @core.Inline::Text(prefix.to_string() + " "),
      @core.Inline::InlineMath(
        @core.MathExpr::Limits(
          @core.MathExpr::Sym("∑"),
          Some(@core.MathExpr::Sym("abcde")),
          None,
        ),
      ),
    ]),
  )

  let ctx = @core.StyleContext::default()
  let page = LayoutEngine::new(ctx).layout_doc(doc)
  let max_x = ctx.page_width - ctx.margin_x
  for box in page.boxes {
    match box.kind {
      BoxKind::Text(_, _, _, _) =>
        assert_eq(box.rect.x + box.rect.w <= max_x + 0.01, true)
      _ => ()
    }
  }
}
