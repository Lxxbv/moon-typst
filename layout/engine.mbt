///|
/// Layout Engine calculating geometric positions and box structures for Typst documents

pub struct LayoutEngine {
  ctx : @core.StyleContext
  mut cur_x : Double
  mut cur_y : Double
  boxes : Array[LayoutBox]
}

pub fn LayoutEngine::new(ctx : @core.StyleContext) -> LayoutEngine {
  {
    ctx,
    cur_x: ctx.margin_x,
    cur_y: ctx.margin_y,
    boxes: [],
  }
}

///|
/// Approximate string display width based on font size and character classification
pub fn measure_text_width(text : String, font_size : Double) -> Double {
  let mut total = 0.0
  let len = text.length()
  for i = 0; i < len; i = i + 1 {
    let code = text[i].to_int()
    if code > 255 {
      total = total + font_size * 1.0 // CJK and wide characters
    } else if code == 32 {
      total = total + font_size * 0.3 // space
    } else if code == 105 || code == 108 || code == 116 || code == 46 || code == 44 {
      total = total + font_size * 0.35 // narrow letters i, l, t, ., ,
    } else if code == 109 || code == 119 || code == 77 || code == 87 {
      total = total + font_size * 0.8 // wide letters m, w, M, W
    } else {
      total = total + font_size * 0.55 // average latin letter
    }
  }
  total
}

///|
/// Main layout computation entrypoint
pub fn LayoutEngine::layout_doc(self : LayoutEngine, doc : @core.Doc) -> PageLayout {
  for block in doc.blocks {
    self.layout_block(block)
  }
  let final_height = if self.cur_y + self.ctx.margin_y > self.ctx.page_height {
    self.cur_y + self.ctx.margin_y
  } else {
    self.ctx.page_height
  }
  {
    width: self.ctx.page_width,
    height: final_height,
    boxes: self.boxes,
  }
}

fn LayoutEngine::layout_block(self : LayoutEngine, block : @core.Block) -> Unit {
  match block {
    @core.Block::Heading(level, inlines) => self.layout_heading(level, inlines)
    @core.Block::Paragraph(inlines) => self.layout_paragraph(inlines)
    @core.Block::CodeBlock(lang, code) => self.layout_code_block(lang, code)
    @core.Block::MathBlock(expr) => self.layout_math_block(expr)
    @core.Block::List(ordered, items) => self.layout_list(ordered, items)
    @core.Block::Table(cols, rows) => self.layout_table(cols, rows)
    @core.Block::HorizontalRule => self.layout_horizontal_rule()
  }
}

fn LayoutEngine::layout_heading(
  self : LayoutEngine,
  level : Int,
  inlines : Array[@core.Inline]
) -> Unit {
  let scale = match level {
    1 => 1.8
    2 => 1.4
    3 => 1.2
    _ => 1.1
  }
  let font_size = self.ctx.font_size * scale
  let top_margin = match level {
    1 => 24.0
    2 => 18.0
    _ => 14.0
  }
  self.cur_y = self.cur_y + top_margin
  self.cur_x = self.ctx.margin_x

  for inline in inlines {
    self.layout_inline_styled(inline, font_size, self.ctx.text_color, "bold")
  }

  self.cur_y = self.cur_y + font_size * 1.3
  self.cur_x = self.ctx.margin_x
}

fn LayoutEngine::layout_paragraph(
  self : LayoutEngine,
  inlines : Array[@core.Inline]
) -> Unit {
  self.cur_x = self.ctx.margin_x
  let font_size = self.ctx.font_size
  let line_h = font_size * self.ctx.line_height

  for inline in inlines {
    self.layout_inline_styled(inline, font_size, self.ctx.text_color, "normal")
  }

  self.cur_y = self.cur_y + line_h + 8.0 // paragraph bottom spacing
  self.cur_x = self.ctx.margin_x
}

fn LayoutEngine::layout_inline_styled(
  self : LayoutEngine,
  inline : @core.Inline,
  font_size : Double,
  color : String,
  weight : String
) -> Unit {
  let max_x = self.ctx.page_width - self.ctx.margin_x
  let line_h = font_size * self.ctx.line_height

  match inline {
    @core.Inline::Text(text) => {
      let w = measure_text_width(text, font_size)
      if self.cur_x + w > max_x && self.cur_x > self.ctx.margin_x {
        self.cur_y = self.cur_y + line_h
        self.cur_x = self.ctx.margin_x
      }
      let b = LayoutBox::new(
        Rect::new(self.cur_x, self.cur_y, w, font_size),
        BoxKind::Text(text, font_size, color, weight),
      )
      self.boxes.push(b)
      self.cur_x = self.cur_x + w
    }
    @core.Inline::Bold(inners) => {
      for inner in inners {
        self.layout_inline_styled(inner, font_size, color, "bold")
      }
    }
    @core.Inline::Italic(inners) => {
      for inner in inners {
        self.layout_inline_styled(inner, font_size, color, "italic")
      }
    }
    @core.Inline::Code(code) => {
      let w = measure_text_width(code, font_size * 0.9)
      if self.cur_x + w > max_x && self.cur_x > self.ctx.margin_x {
        self.cur_y = self.cur_y + line_h
        self.cur_x = self.ctx.margin_x
      }
      // Draw background pill for inline code
      let bg = LayoutBox::new(
        Rect::new(self.cur_x - 2.0, self.cur_y - 2.0, w + 4.0, font_size + 4.0),
        BoxKind::RectFill(w + 4.0, font_size + 4.0, self.ctx.code_bg_color, 3.0),
      )
      self.boxes.push(bg)
      let b = LayoutBox::new(
        Rect::new(self.cur_x, self.cur_y, w, font_size),
        BoxKind::Text(code, font_size * 0.9, "#d73a49", "monospace"),
      )
      self.boxes.push(b)
      self.cur_x = self.cur_x + w + 4.0
    }
    @core.Inline::InlineMath(expr) => {
      self.layout_inline_math(expr, font_size)
    }
    @core.Inline::Link(url, text) => {
      let display = if text.length() > 0 { text } else { url }
      let w = measure_text_width(display, font_size)
      let b = LayoutBox::new(
        Rect::new(self.cur_x, self.cur_y, w, font_size),
        BoxKind::Text(display, font_size, "#0969da", "normal"),
      )
      self.boxes.push(b)
      self.cur_x = self.cur_x + w
    }
    @core.Inline::LineBreak => {
      self.cur_y = self.cur_y + line_h
      self.cur_x = self.ctx.margin_x
    }
  }
}

fn LayoutEngine::layout_inline_math(
  self : LayoutEngine,
  expr : @core.MathExpr,
  font_size : Double
) -> Unit {
  match expr {
    @core.MathExpr::Sym(s) => {
      let w = measure_text_width(s, font_size)
      let b = LayoutBox::new(
        Rect::new(self.cur_x, self.cur_y, w, font_size),
        BoxKind::Text(s, font_size, "#24292f", "italic"),
      )
      self.boxes.push(b)
      self.cur_x = self.cur_x + w
    }
    @core.MathExpr::Op(op) => {
      let w = measure_text_width(" " + op + " ", font_size)
      let b = LayoutBox::new(
        Rect::new(self.cur_x, self.cur_y, w, font_size),
        BoxKind::Text(" " + op + " ", font_size, "#24292f", "normal"),
      )
      self.boxes.push(b)
      self.cur_x = self.cur_x + w
    }
    @core.MathExpr::Frac(num, den) => {
      let num_str = match num {
        @core.MathExpr::Sym(s) => s
        _ => "n"
      }
      let den_str = match den {
        @core.MathExpr::Sym(s) => s
        _ => "d"
      }
      let nw = measure_text_width(num_str, font_size * 0.8)
      let dw = measure_text_width(den_str, font_size * 0.8)
      let base_w = if nw > dw { nw } else { dw }
      let max_w = base_w + 8.0

      // Fraction bar
      let bar = LayoutBox::new(
        Rect::new(self.cur_x, self.cur_y + font_size * 0.5, max_w, 1.0),
        BoxKind::Line(self.cur_x, self.cur_y + font_size * 0.5, self.cur_x + max_w, self.cur_y + font_size * 0.5, "#24292f", 1.0),
      )
      self.boxes.push(bar)

      // Numerator
      let nb = LayoutBox::new(
        Rect::new(self.cur_x + (max_w - nw) / 2.0, self.cur_y - font_size * 0.4, nw, font_size * 0.8),
        BoxKind::Text(num_str, font_size * 0.8, "#24292f", "italic"),
      )
      self.boxes.push(nb)

      // Denominator
      let db = LayoutBox::new(
        Rect::new(self.cur_x + (max_w - dw) / 2.0, self.cur_y + font_size * 0.7, dw, font_size * 0.8),
        BoxKind::Text(den_str, font_size * 0.8, "#24292f", "italic"),
      )
      self.boxes.push(db)

      self.cur_x = self.cur_x + max_w + 4.0
    }
    @core.MathExpr::Sqrt(inner) => {
      let sym_w = measure_text_width("√", font_size)
      let b = LayoutBox::new(
        Rect::new(self.cur_x, self.cur_y, sym_w, font_size),
        BoxKind::Text("√", font_size, "#24292f", "normal"),
      )
      self.boxes.push(b)
      self.cur_x = self.cur_x + sym_w
      self.layout_inline_math(inner, font_size)
    }
    @core.MathExpr::Group(items) => {
      for item in items {
        self.layout_inline_math(item, font_size)
      }
    }
    @core.MathExpr::SubSup(base, sub, sup) => {
      self.layout_inline_math(base, font_size)
      match sub {
        Some(s) => {
          let old_y = self.cur_y
          self.cur_y = self.cur_y + font_size * 0.3
          self.layout_inline_math(s, font_size * 0.7)
          self.cur_y = old_y
        }
        None => ()
      }
      match sup {
        Some(s) => {
          let old_y = self.cur_y
          self.cur_y = self.cur_y - font_size * 0.4
          self.layout_inline_math(s, font_size * 0.7)
          self.cur_y = old_y
        }
        None => ()
      }
    }
  }
}

fn LayoutEngine::layout_math_block(
  self : LayoutEngine,
  expr : @core.MathExpr
) -> Unit {
  self.cur_y = self.cur_y + 16.0
  self.cur_x = self.ctx.margin_x + 32.0 // centered/indented block
  let font_size = self.ctx.font_size * 1.2
  self.layout_inline_math(expr, font_size)
  self.cur_y = self.cur_y + font_size * 1.5 + 16.0
  self.cur_x = self.ctx.margin_x
}

fn LayoutEngine::layout_code_block(
  self : LayoutEngine,
  _lang : String,
  code : String
) -> Unit {
  self.cur_y = self.cur_y + 8.0
  let padding = 16.0
  let font_size = self.ctx.font_size * 0.85
  let line_h = font_size * 1.4

  let lines : Array[String] = []
  let buf = StringBuilder()
  let len = code.length()
  for i = 0; i < len; i = i + 1 {
    let c = code[i].to_int().unsafe_to_char()
    if c == '\n' {
      lines.push(buf.to_string())
      buf.reset()
    } else if c != '\r' {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    lines.push(buf.to_string())
  }

  let block_h = padding * 2.0 + (lines.length().to_double()) * line_h
  let block_w = self.ctx.content_width()

  // Background box
  let bg = LayoutBox::new(
    Rect::new(self.ctx.margin_x, self.cur_y, block_w, block_h),
    BoxKind::RectFill(block_w, block_h, self.ctx.code_bg_color, 6.0),
  )
  self.boxes.push(bg)

  // Border outline
  let stroke = LayoutBox::new(
    Rect::new(self.ctx.margin_x, self.cur_y, block_w, block_h),
    BoxKind::RectStroke(block_w, block_h, "#e1e4e8", 1.0),
  )
  self.boxes.push(stroke)

  // Text lines
  let mut text_y = self.cur_y + padding
  for line in lines {
    let b = LayoutBox::new(
      Rect::new(self.ctx.margin_x + padding, text_y, block_w - padding * 2.0, font_size),
      BoxKind::Text(line, font_size, "#24292e", "monospace"),
    )
    self.boxes.push(b)
    text_y = text_y + line_h
  }

  self.cur_y = self.cur_y + block_h + 12.0
  self.cur_x = self.ctx.margin_x
}

fn LayoutEngine::layout_list(
  self : LayoutEngine,
  ordered : Bool,
  items : Array[Array[@core.Inline]]
) -> Unit {
  self.cur_y = self.cur_y + 4.0
  let font_size = self.ctx.font_size
  let line_h = font_size * self.ctx.line_height

  for i, item in items {
    self.cur_x = self.ctx.margin_x + 16.0
    let bullet = if ordered { "\{i + 1}. " } else { "• " }
    let bullet_w = measure_text_width(bullet, font_size)
    let bb = LayoutBox::new(
      Rect::new(self.cur_x, self.cur_y, bullet_w, font_size),
      BoxKind::Text(bullet, font_size, "#0969da", "bold"),
    )
    self.boxes.push(bb)
    self.cur_x = self.cur_x + bullet_w + 4.0

    for inline in item {
      self.layout_inline_styled(inline, font_size, self.ctx.text_color, "normal")
    }
    self.cur_y = self.cur_y + line_h + 4.0
  }
  self.cur_y = self.cur_y + 8.0
  self.cur_x = self.ctx.margin_x
}

fn LayoutEngine::layout_horizontal_rule(self : LayoutEngine) -> Unit {
  self.cur_y = self.cur_y + 12.0
  let line_w = self.ctx.content_width()
  let b = LayoutBox::new(
    Rect::new(self.ctx.margin_x, self.cur_y, line_w, 1.0),
    BoxKind::Line(self.ctx.margin_x, self.cur_y, self.ctx.margin_x + line_w, self.cur_y, "#d0d7de", 1.0),
  )
  self.boxes.push(b)
  self.cur_y = self.cur_y + 16.0
  self.cur_x = self.ctx.margin_x
}

fn LayoutEngine::layout_table(
  self : LayoutEngine,
  cols : Int,
  cells : Array[Array[@core.Inline]]
) -> Unit {
  self.cur_y = self.cur_y + 12.0
  let table_w = self.ctx.content_width()
  let col_w = table_w / cols.to_double()
  let cell_h = self.ctx.font_size * 2.2

  for i, cell in cells {
    let col_idx = i % cols
    let row_idx = i / cols
    let cell_x = self.ctx.margin_x + col_idx.to_double() * col_w
    let cell_y = self.cur_y + row_idx.to_double() * cell_h

    // Cell border
    let stroke = LayoutBox::new(
      Rect::new(cell_x, cell_y, col_w, cell_h),
      BoxKind::RectStroke(col_w, cell_h, "#e1e4e8", 1.0),
    )
    self.boxes.push(stroke)

    // Cell content
    self.cur_x = cell_x + 8.0
    let orig_y = self.cur_y
    self.cur_y = cell_y + 8.0
    for inline in cell {
      self.layout_inline_styled(inline, self.ctx.font_size, self.ctx.text_color, "normal")
    }
    self.cur_y = orig_y
  }

  let total_rows = (cells.length() + cols - 1) / cols
  self.cur_y = self.cur_y + total_rows.to_double() * cell_h + 16.0
  self.cur_x = self.ctx.margin_x
}
