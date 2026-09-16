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
