///|
test "parse_typst full document" {
  let src =
    #|= Introduction
    #|
    #|This is a *bold* and _italic_ statement with `code`.
    #|
    #|== Mathematical Formulation
    #|
    #|$ E = m c^2 $
    #|
    #|Here is an inline formula: $a / b + c$.
    #|
    #|=== Implementation
    #|
    #|```moonbit
    #|fn hello() -> Unit {
    #|  println("Hi")
    #|}
    #|```
    #|
    #|- Item Alpha
    #|- Item Beta
    #|
    #|+ Step One
    #|+ Step Two
    #|
    #|---
  let doc = parse_typst(src)
  assert_eq(doc.blocks.length(), 10)

  // Block 0: Heading 1
  match doc.blocks[0] {
    @core.Block::Heading(1, [@core.Inline::Text("Introduction")]) => ()
    _ => abort("expected heading 1")
  }

  // Block 1: Paragraph with bold, italic, code
  match doc.blocks[1] {
    @core.Block::Paragraph(inlines) => assert_eq(inlines.length(), 7)
    _ => abort("expected paragraph")
  }

  // Block 2: Heading 2
  match doc.blocks[2] {
    @core.Block::Heading(2, [@core.Inline::Text("Mathematical Formulation")]) =>
      ()
    _ => abort("expected heading 2")
  }

  // Block 3: MathBlock
  match doc.blocks[3] {
    @core.Block::MathBlock(_) => ()
    _ => abort("expected MathBlock")
  }

  // Block 4: Paragraph with inline math
  match doc.blocks[4] {
    @core.Block::Paragraph(inlines) => {
      let has_math = inlines.any(fn(i) {
        match i {
          @core.Inline::InlineMath(_) => true
          _ => false
        }
      })
      assert_eq(has_math, true)
    }
    _ => abort("expected paragraph with inline math")
  }

  // Block 5: Heading 3
  match doc.blocks[5] {
    @core.Block::Heading(3, [@core.Inline::Text("Implementation")]) => ()
    _ => abort("expected heading 3")
  }

  // Block 6: CodeBlock
  match doc.blocks[6] {
    @core.Block::CodeBlock("moonbit", code) => {
      let has_fn = code.contains("fn hello")
      assert_eq(has_fn, true)
    }
    _ => abort("expected CodeBlock")
  }

  // Block 7: Bullet List
  match doc.blocks[7] {
    @core.Block::List(false, items) => assert_eq(items.length(), 2)
    _ => abort("expected bullet list")
  }

  // Block 8: Numbered List
  match doc.blocks[8] {
    @core.Block::List(true, items) => assert_eq(items.length(), 2)
    _ => abort("expected numbered list")
  }
}

///|
test "parse_typst edge cases: unclosed markup and empty lines" {
  let src = "*unclosed bold and _unclosed italic\n\nJust text."
  let doc = parse_typst(src)
  assert_eq(doc.blocks.length(), 2)

  let empty_doc = parse_typst("\n\n\n")
  assert_eq(empty_doc.blocks.length(), 0)
}

///|
test "parse_typst math expressions" {
  let src = "$ a / b = sqrt(c) $"
  let doc = parse_typst(src)
  assert_eq(doc.blocks.length(), 1)
  match doc.blocks[0] {
    @core.Block::MathBlock(expr) =>
      match expr {
        @core.MathExpr::Group(items) => {
          assert_eq(items.length(), 3)
          match items[0] {
            @core.MathExpr::Frac(
              @core.MathExpr::Sym("a"),
              @core.MathExpr::Sym("b")
            ) => ()
            _ => abort("expected Frac")
          }
          match items[1] {
            @core.MathExpr::Op("=") => ()
            _ => abort("expected Op(=)")
          }
          match items[2] {
            @core.MathExpr::Sqrt(@core.MathExpr::Sym("c")) => ()
            _ => abort("expected Sqrt(c)")
          }
        }
        _ => abort("expected Group in MathBlock")
      }
    _ => abort("expected MathBlock")
  }
}

///|
test "parse_typst matrix and vector math" {
  let src = "$ mat(1, 2; 3, 4) $\n$ vec(a, b) $"
  let doc = parse_typst(src)
  assert_eq(doc.blocks.length(), 2)

  match doc.blocks[0] {
    @core.Block::MathBlock(@core.MathExpr::Matrix(rows, cols, elems)) => {
      assert_eq(rows, 2)
      assert_eq(cols, 2)
      assert_eq(elems.length(), 4)
      assert_eq(elems[0], @core.MathExpr::Sym("1"))
      assert_eq(elems[3], @core.MathExpr::Sym("4"))
    }
    _ => abort("expected 2x2 Matrix")
  }

  match doc.blocks[1] {
    @core.Block::MathBlock(@core.MathExpr::Vec(elems)) => {
      assert_eq(elems.length(), 2)
      assert_eq(elems[0], @core.MathExpr::Sym("a"))
      assert_eq(elems[1], @core.MathExpr::Sym("b"))
    }
    _ => abort("expected Vec")
  }
}

///|
test "parse_typst accents in math" {
  let src = "$ hat(x) + bar(y) $"
  let doc = parse_typst(src)
  assert_eq(doc.blocks.length(), 1)
  match doc.blocks[0] {
    @core.Block::MathBlock(@core.MathExpr::Group(items)) => {
      assert_eq(items.length(), 3)
      assert_eq(
        items[0],
        @core.MathExpr::Accent(@core.MathExpr::Sym("x"), "hat"),
      )
      assert_eq(items[1], @core.MathExpr::Op("+"))
      assert_eq(
        items[2],
        @core.MathExpr::Accent(@core.MathExpr::Sym("y"), "bar"),
      )
    }
    _ => abort("expected accent group")
  }
}

///|
test "parse_typst hash blocks" {
  let src = "#pagebreak()\n#rect\n#circle\n#grid"
  let doc = parse_typst(src)
  assert_eq(doc.blocks.length(), 4)

  match doc.blocks[0] {
    @core.Block::PageBreak => ()
    _ => abort("expected PageBreak")
  }
  match doc.blocks[1] {
    @core.Block::Shape(@core.ShapeKind::Rect(_, _, _), _) => ()
    _ => abort("expected Rect Shape")
  }
  match doc.blocks[2] {
    @core.Block::Shape(@core.ShapeKind::Circle(_), _) => ()
    _ => abort("expected Circle Shape")
  }
  match doc.blocks[3] {
    @core.Block::Grid(_, _) => ()
    _ => abort("expected Grid")
  }
}

///|
test "pipe table groups physical rows and complete cells" {
  let src = "| Name | Formula (short) | Value | Note |\n| One | a (b) | 12 | ok |\n| Two | c (d) | 34 | yes |"
  let doc = parse_typst(src)
  assert_eq(doc.blocks.length(), 1)
  match doc.blocks[0] {
    @core.Block::Table(table) => {
      assert_eq(table.alignments.length(), 4)
      assert_eq(table.header_rows, 0)
      assert_eq(table.rows.length(), 3)
      assert_eq(table.rows[0].length(), 4)
      assert_eq(table.rows[1].length(), 4)
      assert_eq(table.rows[0][0], [@core.Inline::Text("Name")])
      assert_eq(table.rows[0][1], [
        @core.Inline::Text("Formula "),
        @core.Inline::Text("("),
        @core.Inline::Text("short"),
        @core.Inline::Text(")"),
      ])
    }
    _ => abort("expected table")
  }
}

///|
test "trailing outside pipe followed by whitespace adds no table cell" {
  let doc = parse_typst("| a | b | ")
  assert_eq(doc.blocks.length(), 1)
  match doc.blocks[0] {
    @core.Block::Table(table) => {
      assert_eq(table.alignments.length(), 2)
      assert_eq(table.rows.length(), 1)
      assert_eq(table.rows[0].length(), 2)
      assert_eq(table.rows[0][0], [@core.Inline::Text("a")])
      assert_eq(table.rows[0][1], [@core.Inline::Text("b")])
    }
    _ => abort("expected two-cell table")
  }
}

///|
test "unbordered pipe table leaves following prose as paragraph" {
  let doc = parse_typst("Alpha | Beta\nOne | Two\nFollowing prose")
  assert_eq(doc.blocks.length(), 2)
  match doc.blocks[0] {
    @core.Block::Table(table) => {
      assert_eq(table.alignments.length(), 2)
      assert_eq(table.rows.length(), 2)
      assert_eq(table.rows[0].length(), 2)
      assert_eq(table.rows[1].length(), 2)
    }
    _ => abort("expected table")
  }
  match doc.blocks[1] {
    @core.Block::Paragraph(_) => ()
    _ => abort("expected following paragraph")
  }
}

///|
test "single unbordered pipe line remains prose" {
  let doc = parse_typst(
    "Systems & Compiler Engineer | alex@example.com | GitHub",
  )
  assert_eq(doc.blocks.length(), 1)
  match doc.blocks[0] {
    @core.Block::Paragraph(_) => ()
    _ => abort("expected a prose paragraph")
  }
}

///|
test "one-row unbordered pipe content remains prose" {
  let doc = parse_typst("Alpha | Beta")
  assert_eq(doc.blocks.length(), 1)
  match doc.blocks[0] {
    @core.Block::Paragraph(_) => ()
    _ => abort("expected an unbordered single line to remain prose")
  }
}

///|
test "table separator records header and column alignment" {
  let doc = parse_typst(
    "| Left | Middle | Right | Plain |\n| :--- | :---: | ---: | --- |\n| a | b | c | d |",
  )
  match doc.blocks[0] {
    @core.Block::Table(table) => {
      assert_eq(table.header_rows, 1)
      assert_eq(table.rows.length(), 2)
      assert_eq(table.alignments, [
        @core.TableAlignment::Left,
        @core.TableAlignment::Center,
        @core.TableAlignment::Right,
        @core.TableAlignment::Left,
      ])
    }
    _ => abort("expected table")
  }
}

///|
test "table retains inline markup and pads ragged rows" {
  let doc = parse_typst(
    "| *bold* and _italic_ | `code` |\n| short |\n| x | y | z |",
  )
  match doc.blocks[0] {
    @core.Block::Table(table) => {
      assert_eq(table.rows.length(), 3)
      assert_eq(table.alignments.length(), 3)
      assert_eq(table.rows[0].length(), 3)
      assert_eq(table.rows[1][1], [])
      assert_eq(table.rows[1][2], [])
      assert_eq(table.rows[0][0], [
        @core.Inline::Bold([@core.Inline::Text("bold")]),
        @core.Inline::Text(" and "),
        @core.Inline::Italic([@core.Inline::Text("italic")]),
      ])
      assert_eq(table.rows[0][1], [@core.Inline::Code("code")])
    }
    _ => abort("expected table")
  }
}

///|
test "table ends before prose and keeps later separator-shaped rows" {
  let doc = parse_typst("| a | b |\n| c | d |\n| --- | --- |\nAfter the table")
  assert_eq(doc.blocks.length(), 2)
  match doc.blocks[0] {
    @core.Block::Table(table) => {
      assert_eq(table.header_rows, 0)
      assert_eq(table.rows.length(), 3)
      assert_eq(table.rows[2][0], [@core.Inline::Text("---")])
    }
    _ => abort("expected table")
  }
  match doc.blocks[1] {
    @core.Block::Paragraph([@core.Inline::Text("After the table")]) => ()
    _ => abort("expected prose after table")
  }
}

///|
test "table keeps malformed separator width as data" {
  let doc = parse_typst("| a | b | c |\n| --- | --- |\n| d | e | f |")
  match doc.blocks[0] {
    @core.Block::Table(table) => {
      assert_eq(table.header_rows, 0)
      assert_eq(table.rows.length(), 3)
      assert_eq(table.rows[1][0], [@core.Inline::Text("---")])
      assert_eq(table.rows[1][2], [])
    }
    _ => abort("expected table")
  }
}

///|
test "table accepts mixed outside pipes and an unbordered separator" {
  let doc = parse_typst(
    "a | b\n--- | :---:\n| left | centered\nright | value |",
  )
  match doc.blocks[0] {
    @core.Block::Table(table) => {
      assert_eq(table.header_rows, 1)
      assert_eq(table.rows.length(), 3)
      assert_eq(table.alignments, [
        @core.TableAlignment::Left,
        @core.TableAlignment::Center,
      ])
      assert_eq(table.rows[1][0], [@core.Inline::Text("left")])
      assert_eq(table.rows[2][1], [@core.Inline::Text("value")])
    }
    _ => abort("expected table")
  }
}

///|
test "pipe inside inline math remains a paragraph" {
  let doc = parse_typst("text $a|b$")
  assert_eq(doc.blocks.length(), 1)
  match doc.blocks[0] {
    @core.Block::Paragraph(
      [@core.Inline::Text("text "), @core.Inline::InlineMath(_)]
    ) => ()
    _ => abort("expected paragraph with inline math")
  }
}

///|
test "pipe inside bold remains a paragraph" {
  let doc = parse_typst("text *a|b*")
  assert_eq(doc.blocks.length(), 1)
  match doc.blocks[0] {
    @core.Block::Paragraph(
      [
        @core.Inline::Text("text "),
        @core.Inline::Bold(
          [
            @core.Inline::Text("a"),
            @core.Inline::Text("|"),
            @core.Inline::Text("b"),
          ]
        ),
      ]
    ) => ()
    _ => abort("expected paragraph with bold")
  }
}

///|
test "pipe inside italic remains a paragraph" {
  let doc = parse_typst("text _a|b_")
  assert_eq(doc.blocks.length(), 1)
  match doc.blocks[0] {
    @core.Block::Paragraph(
      [
        @core.Inline::Text("text "),
        @core.Inline::Italic(
          [
            @core.Inline::Text("a"),
            @core.Inline::Text("|"),
            @core.Inline::Text("b"),
          ]
        ),
      ]
    ) => ()
    _ => abort("expected paragraph with italic")
  }
}

///|
test "pipe after inline span remains a table delimiter" {
  let doc = parse_typst("*a|b* | Beta\nOne | Two")
  assert_eq(doc.blocks.length(), 1)
  match doc.blocks[0] {
    @core.Block::Table(table) => {
      assert_eq(table.rows.length(), 2)
      assert_eq(table.rows[0].length(), 2)
      assert_eq(table.rows[0][0], [
        @core.Inline::Bold([
          @core.Inline::Text("a"),
          @core.Inline::Text("|"),
          @core.Inline::Text("b"),
        ]),
      ])
      assert_eq(table.rows[0][1], [@core.Inline::Text("Beta")])
    }
    _ => abort("expected unbordered table")
  }
}

///|
test "line starting with inline math can be an unbordered table" {
  let doc = parse_typst("$a$ | b\nc | d")
  assert_eq(doc.blocks.length(), 1)
  match doc.blocks[0] {
    @core.Block::Table(table) => {
      assert_eq(table.rows.length(), 2)
      assert_eq(table.rows[0].length(), 2)
      match table.rows[0][0] {
        [@core.Inline::InlineMath(_)] => ()
        _ => abort("expected inline math in first cell")
      }
      assert_eq(table.rows[0][1], [@core.Inline::Text("b")])
      assert_eq(table.rows[1][0], [@core.Inline::Text("c")])
      assert_eq(table.rows[1][1], [@core.Inline::Text("d")])
    }
    _ => abort("expected unbordered table starting with inline math")
  }
}
