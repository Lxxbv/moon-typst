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
  let texts : Array[Rect] = []
  for box in page.boxes {
    match box.kind {
      BoxKind::RectStroke(_, _, _, _) => borders.push(box.rect)
      BoxKind::Text(_, _, _, _) => texts.push(box.rect)
      _ => ()
    }
  }
  assert_eq(borders.length(), 4)
  assert_eq(borders[0].w, borders[1].w)
  assert_eq(borders[0].x + borders[0].w, borders[1].x)
  assert_eq(borders[0].h > ctx.font_size * 2.2, true)
  assert_eq(borders[2].y, borders[0].y + borders[0].h)
  assert_eq(borders[3].y, borders[2].y)
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
