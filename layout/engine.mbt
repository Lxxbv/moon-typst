///|
/// Layout Engine calculating geometric positions and box structures for Typst documents
pub struct LayoutEngine {
  ctx : @core.StyleContext
  mut cur_x : Double
  mut cur_y : Double
  boxes : Array[LayoutBox]
}

///|
priv struct TableCellFlow {
  x0 : Double
  max_x : Double
  mut x : Double
  mut y : Double
  mut bottom : Double
  mut line_bottom : Double
  line_h : Double
  mut line_start : Int
  align : @core.TableAlignment
}

///|
pub fn LayoutEngine::new(ctx : @core.StyleContext) -> LayoutEngine {
  { ctx, cur_x: ctx.margin_x, cur_y: ctx.margin_y, boxes: [], }
}

///|
/// Approximate string display width based on font size and character classification
pub fn measure_text_width(text : String, font_size : Double) -> Double {
  let mut total = 0.0
  for character in text {
    let code = character.to_int()
    if code > 255 {
      total = total + font_size * 1.0 // CJK and wide characters
    } else if code == 32 {
      total = total + font_size * 0.3 // space
    } else if code == 105 ||
      code == 108 ||
      code == 116 ||
      code == 46 ||
      code == 44 {
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
pub fn LayoutEngine::layout_doc(
  self : LayoutEngine,
  doc : @core.Doc,
) -> PageLayout {
  for block in doc.blocks {
    self.layout_block(block)
  }
  let final_height = if self.cur_y + self.ctx.margin_y > self.ctx.page_height {
    self.cur_y + self.ctx.margin_y
  } else {
    self.ctx.page_height
  }
  { width: self.ctx.page_width, height: final_height, boxes: self.boxes, }
}

///|
fn LayoutEngine::layout_block(self : LayoutEngine, block : @core.Block) -> Unit {
  match block {
    @core.Block::Heading(level, inlines) => self.layout_heading(level, inlines)
    @core.Block::Paragraph(inlines) => self.layout_paragraph(inlines)
    @core.Block::CodeBlock(lang, code) => self.layout_code_block(lang, code)
    @core.Block::MathBlock(expr) => self.layout_math_block(expr)
    @core.Block::List(ordered, items) => self.layout_list(ordered, items)
    @core.Block::Table(table) => self.layout_table(table)
    @core.Block::Shape(shape, style) => self.layout_shape(shape, style)
    @core.Block::Grid(cols, items) => self.layout_grid(cols, items)
    @core.Block::FootnoteBlock(index, inlines) =>
      self.layout_footnote_block(index, inlines)
    @core.Block::Figure(body, caption) => self.layout_figure(body, caption)
    @core.Block::AlignBlock(align, body) => self.layout_align_block(align, body)
    @core.Block::HorizontalRule => self.layout_horizontal_rule()
    @core.Block::PageBreak => self.layout_page_break()
  }
}

///|
fn LayoutEngine::layout_heading(
  self : LayoutEngine,
  level : Int,
  inlines : Array[@core.Inline],
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

///|
fn LayoutEngine::layout_paragraph(
  self : LayoutEngine,
  inlines : Array[@core.Inline],
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

///|
fn LayoutEngine::layout_inline_text(
  self : LayoutEngine,
  text : String,
  font_size : Double,
  color : String,
  weight : String,
) -> Unit {
  let mut segment = StringBuilder()
  let mut pending_spaces = StringBuilder()
  let mut segment_kind = 0
  let line_h = font_size * self.ctx.line_height
  let mut previous_was_cr = false
  for character in text {
    if previous_was_cr && character == '\n' {
      previous_was_cr = false
    } else {
      previous_was_cr = character == '\r'
      let code = character.to_int()
      if character == '\n' || character == '\r' {
        if segment_kind != 0 {
          self.layout_text_segment(
            segment.to_string(),
            pending_spaces.to_string(),
            segment_kind == 2,
            font_size,
            line_h,
            color,
            weight,
          )
          segment_kind = 0
          segment = StringBuilder()
        }
        pending_spaces = StringBuilder()
        self.cur_y = self.cur_y + line_h
        self.cur_x = self.ctx.margin_x
      } else if character == ' ' || character == '\t' {
        if segment_kind != 0 {
          self.layout_text_segment(
            segment.to_string(),
            pending_spaces.to_string(),
            segment_kind == 2,
            font_size,
            line_h,
            color,
            weight,
          )
          segment_kind = 0
          segment = StringBuilder()
          pending_spaces = StringBuilder()
        }
        pending_spaces.write_char(
          if character == '\t' {
            ' '
          } else {
            character
          },
        )
      } else if code > 255 {
        if segment_kind != 2 && segment_kind != 0 {
          self.layout_text_segment(
            segment.to_string(),
            pending_spaces.to_string(),
            false,
            font_size,
            line_h,
            color,
            weight,
          )
          segment_kind = 0
          segment = StringBuilder()
          pending_spaces = StringBuilder()
        }
        segment_kind = 2
        segment.write_char(character)
      } else {
        if segment_kind != 1 && segment_kind != 0 {
          self.layout_text_segment(
            segment.to_string(),
            pending_spaces.to_string(),
            true,
            font_size,
            line_h,
            color,
            weight,
          )
          segment_kind = 0
          segment = StringBuilder()
          pending_spaces = StringBuilder()
        }
        segment_kind = 1
        segment.write_char(character)
      }
    }
  }
  if segment_kind != 0 {
    self.layout_text_segment(
      segment.to_string(),
      pending_spaces.to_string(),
      segment_kind == 2,
      font_size,
      line_h,
      color,
      weight,
    )
  }
}

///|
fn LayoutEngine::layout_text_segment(
  self : LayoutEngine,
  text : String,
  pending_spaces : String,
  is_wide_text : Bool,
  font_size : Double,
  line_h : Double,
  color : String,
  weight : String,
) -> Unit {
  let max_x = self.ctx.page_width - self.ctx.margin_x
  let available_width = max_x - self.ctx.margin_x
  let spaces = if self.cur_x > self.ctx.margin_x { pending_spaces } else { "" }
  let candidate = spaces + text
  let candidate_width = measure_text_width(candidate, font_size)
  let mut wrapped_candidate = candidate
  if self.cur_x > self.ctx.margin_x && self.cur_x + candidate_width > max_x {
    self.cur_y = self.cur_y + line_h
    self.cur_x = self.ctx.margin_x
    wrapped_candidate = text
  }

  let width = measure_text_width(wrapped_candidate, font_size)
  if is_wide_text || width > available_width {
    self.layout_wrappable_characters(
      wrapped_candidate, font_size, line_h, color, weight, max_x,
    )
  } else {
    self.place_text_box(wrapped_candidate, width, font_size, color, weight)
  }
}

///|
fn LayoutEngine::layout_wrappable_characters(
  self : LayoutEngine,
  text : String,
  font_size : Double,
  line_h : Double,
  color : String,
  weight : String,
  max_x : Double,
) -> Unit {
  let mut line = StringBuilder()
  let mut line_width = 0.0
  for character in text {
    let glyph = StringBuilder()
    glyph.write_char(character)
    let glyph_text = glyph.to_string()
    let glyph_width = measure_text_width(glyph_text, font_size)
    if line_width > 0.0 && self.cur_x + line_width + glyph_width > max_x {
      let line_text = line.to_string()
      self.place_text_box(line_text, line_width, font_size, color, weight)
      self.cur_y = self.cur_y + line_h
      self.cur_x = self.ctx.margin_x
      line_width = 0.0
      line = StringBuilder()
    } else if line_width == 0.0 &&
      self.cur_x > self.ctx.margin_x &&
      self.cur_x + glyph_width > max_x {
      self.cur_y = self.cur_y + line_h
      self.cur_x = self.ctx.margin_x
    }
    line.write_char(character)
    line_width = line_width + glyph_width
  }
  if line_width > 0.0 {
    self.place_text_box(line.to_string(), line_width, font_size, color, weight)
  }
}

///|
fn LayoutEngine::place_text_box(
  self : LayoutEngine,
  text : String,
  width : Double,
  font_size : Double,
  color : String,
  weight : String,
) -> Unit {
  self.boxes.push(
    LayoutBox::new(
      Rect::new(self.cur_x, self.cur_y, width, font_size),
      BoxKind::Text(text, font_size, color, weight),
    ),
  )
  self.cur_x = self.cur_x + width
}

///|
fn LayoutEngine::layout_inline_styled(
  self : LayoutEngine,
  inline : @core.Inline,
  font_size : Double,
  color : String,
  weight : String,
) -> Unit {
  let max_x = self.ctx.page_width - self.ctx.margin_x
  let line_h = font_size * self.ctx.line_height

  match inline {
    @core.Inline::Text(text) =>
      self.layout_inline_text(text, font_size, color, weight)
    @core.Inline::Bold(inners) =>
      for inner in inners {
        self.layout_inline_styled(inner, font_size, color, "bold")
      }
    @core.Inline::Italic(inners) =>
      for inner in inners {
        self.layout_inline_styled(inner, font_size, color, "italic")
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
    @core.Inline::InlineMath(expr) => self.layout_inline_math(expr, font_size)
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
    @core.Inline::FootnoteRef(idx) => {
      let num_str = "[\{idx}]"
      let small_size = font_size * 0.75
      let w = measure_text_width(num_str, small_size)
      let b = LayoutBox::new(
        Rect::new(self.cur_x, self.cur_y - font_size * 0.25, w, small_size),
        BoxKind::Text(num_str, small_size, "#0969da", "bold"),
      )
      self.boxes.push(b)
      self.cur_x = self.cur_x + w
    }
    @core.Inline::StyledSpan(inners, custom_color, custom_size) => {
      let use_color = match custom_color {
        Some(c) => c.to_hex()
        None => color
      }
      let use_size = match custom_size {
        Some(s) => s
        None => font_size
      }
      for inner in inners {
        self.layout_inline_styled(inner, use_size, use_color, weight)
      }
    }
    @core.Inline::LineBreak => {
      self.cur_y = self.cur_y + line_h
      self.cur_x = self.ctx.margin_x
    }
  }
}

///|
fn LayoutEngine::layout_inline_math(
  self : LayoutEngine,
  expr : @core.MathExpr,
  font_size : Double,
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
        BoxKind::Line(
          self.cur_x,
          self.cur_y + font_size * 0.5,
          self.cur_x + max_w,
          self.cur_y + font_size * 0.5,
          "#24292f",
          1.0,
        ),
      )
      self.boxes.push(bar)

      // Numerator
      let nb = LayoutBox::new(
        Rect::new(
          self.cur_x + (max_w - nw) / 2.0,
          self.cur_y - font_size * 0.4,
          nw,
          font_size * 0.8,
        ),
        BoxKind::Text(num_str, font_size * 0.8, "#24292f", "italic"),
      )
      self.boxes.push(nb)

      // Denominator
      let db = LayoutBox::new(
        Rect::new(
          self.cur_x + (max_w - dw) / 2.0,
          self.cur_y + font_size * 0.7,
          dw,
          font_size * 0.8,
        ),
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
    @core.MathExpr::Group(items) =>
      for item in items {
        self.layout_inline_math(item, font_size)
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
    @core.MathExpr::Matrix(rows, cols, elems) =>
      self.layout_matrix(rows, cols, elems, font_size)
    @core.MathExpr::Vec(elems) =>
      self.layout_matrix(elems.length(), 1, elems, font_size)
    @core.MathExpr::Accent(inner, acc) =>
      self.layout_accent(inner, acc, font_size)
    @core.MathExpr::Limits(op, lower, upper) =>
      self.layout_limits(op, lower, upper, font_size)
  }
}

///|
fn LayoutEngine::layout_math_block(
  self : LayoutEngine,
  expr : @core.MathExpr,
) -> Unit {
  self.cur_y = self.cur_y + 16.0
  self.cur_x = self.ctx.margin_x + 32.0 // centered/indented block
  let font_size = self.ctx.font_size * 1.2
  self.layout_inline_math(expr, font_size)
  self.cur_y = self.cur_y + font_size * 1.5 + 16.0
  self.cur_x = self.ctx.margin_x
}

///|
fn LayoutEngine::layout_code_block(
  self : LayoutEngine,
  _lang : String,
  code : String,
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

  let block_h = padding * 2.0 + lines.length().to_double() * line_h
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
      Rect::new(
        self.ctx.margin_x + padding,
        text_y,
        block_w - padding * 2.0,
        font_size,
      ),
      BoxKind::Text(line, font_size, "#24292e", "monospace"),
    )
    self.boxes.push(b)
    text_y = text_y + line_h
  }

  self.cur_y = self.cur_y + block_h + 12.0
  self.cur_x = self.ctx.margin_x
}

///|
fn LayoutEngine::layout_list(
  self : LayoutEngine,
  ordered : Bool,
  items : Array[Array[@core.Inline]],
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
      self.layout_inline_styled(
        inline,
        font_size,
        self.ctx.text_color,
        "normal",
      )
    }
    self.cur_y = self.cur_y + line_h + 4.0
  }
  self.cur_y = self.cur_y + 8.0
  self.cur_x = self.ctx.margin_x
}

///|
fn LayoutEngine::layout_horizontal_rule(self : LayoutEngine) -> Unit {
  self.cur_y = self.cur_y + 12.0
  let line_w = self.ctx.content_width()
  let b = LayoutBox::new(
    Rect::new(self.ctx.margin_x, self.cur_y, line_w, 1.0),
    BoxKind::Line(
      self.ctx.margin_x,
      self.cur_y,
      self.ctx.margin_x + line_w,
      self.cur_y,
      "#d0d7de",
      1.0,
    ),
  )
  self.boxes.push(b)
  self.cur_y = self.cur_y + 16.0
  self.cur_x = self.ctx.margin_x
}

///|
fn LayoutEngine::layout_table(
  self : LayoutEngine,
  table : @core.TableData,
) -> Unit {
  self.cur_y = self.cur_y + 12.0
  let table_w = self.ctx.content_width()
  let cols = table.alignments.length()
  if cols == 0 {
    return
  }
  let col_w = table_w / cols.to_double()
  let padding = if col_w < 32.0 { col_w / 4.0 } else { 8.0 }
  let min_h = self.ctx.font_size * 2.2
  for row_idx, row in table.rows {
    let row_y = self.cur_y
    let mut row_h = min_h
    for col_idx = 0; col_idx < cols; col_idx = col_idx + 1 {
      let cell_x = self.ctx.margin_x + col_idx.to_double() * col_w
      let flow : TableCellFlow = {
        x0: cell_x + padding,
        max_x: cell_x + col_w - padding,
        x: cell_x + padding,
        y: row_y + padding,
        bottom: row_y + padding + self.ctx.font_size,
        line_bottom: row_y + padding + self.ctx.font_size,
        line_h: self.ctx.font_size * self.ctx.line_height,
        line_start: self.boxes.length(),
        align: table.alignments[col_idx],
      }
      if col_idx < row.length() {
        let weight = if row_idx < table.header_rows { "bold" } else { "normal" }
        for inline in row[col_idx] {
          self.layout_table_inline(
            flow,
            inline,
            self.ctx.font_size,
            self.ctx.text_color,
            weight,
          )
        }
      }
      self.align_table_line(flow)
      let needed_h = flow.bottom - row_y + padding
      if needed_h > row_h {
        row_h = needed_h
      }
    }
    for col_idx = 0; col_idx < cols; col_idx = col_idx + 1 {
      let cell_x = self.ctx.margin_x + col_idx.to_double() * col_w
      self.boxes.push(
        LayoutBox::new(
          Rect::new(cell_x, row_y, col_w, row_h),
          BoxKind::RectStroke(col_w, row_h, "#e1e4e8", 1.0),
        ),
      )
    }
    self.cur_y = self.cur_y + row_h
  }
  self.cur_y = self.cur_y + 16.0
  self.cur_x = self.ctx.margin_x
}

///|
fn LayoutEngine::align_table_line(
  self : LayoutEngine,
  flow : TableCellFlow,
) -> Unit {
  let line_w = flow.x - flow.x0
  let available = flow.max_x - flow.x0
  let shift = match flow.align {
    @core.TableAlignment::Left => 0.0
    @core.TableAlignment::Center => (available - line_w) / 2.0
    @core.TableAlignment::Right => available - line_w
  }
  for i = flow.line_start; i < self.boxes.length(); i = i + 1 {
    self.boxes[i] = translate_table_box(self.boxes[i], shift, 0.0)
  }
}

///|
fn translate_table_box(box : LayoutBox, dx : Double, dy : Double) -> LayoutBox {
  let rect = box.rect
  let kind = match box.kind {
    BoxKind::Line(x1, y1, x2, y2, color, width) =>
      BoxKind::Line(x1 + dx, y1 + dy, x2 + dx, y2 + dy, color, width)
    other => other
  }
  LayoutBox::new(Rect::new(rect.x + dx, rect.y + dy, rect.w, rect.h), kind)
}

///|
fn LayoutEngine::next_table_line(
  self : LayoutEngine,
  flow : TableCellFlow,
) -> Unit {
  self.align_table_line(flow)
  flow.x = flow.x0
  let next_y = flow.line_bottom + flow.line_h - self.ctx.font_size
  if next_y > flow.y + flow.line_h {
    flow.y = next_y
  } else {
    flow.y = flow.y + flow.line_h
  }
  flow.line_bottom = flow.y + self.ctx.font_size
  if flow.line_bottom > flow.bottom {
    flow.bottom = flow.line_bottom
  }
  flow.line_start = self.boxes.length()
}

///|
fn LayoutEngine::add_table_text(
  self : LayoutEngine,
  flow : TableCellFlow,
  text : String,
  size : Double,
  color : String,
  weight : String,
) -> Unit {
  if text.length() == 0 {
    return
  }
  let width = measure_text_width(text, size)
  self.boxes.push(
    LayoutBox::new(
      Rect::new(flow.x, flow.y, width, size),
      BoxKind::Text(text, size, color, weight),
    ),
  )
  flow.x = flow.x + width
  if flow.y + size > flow.bottom {
    flow.bottom = flow.y + size
  }
  if flow.y + size > flow.line_bottom {
    flow.line_bottom = flow.y + size
  }
}

///|
fn LayoutEngine::layout_table_word(
  self : LayoutEngine,
  flow : TableCellFlow,
  word : String,
  size : Double,
  color : String,
  weight : String,
) -> Unit {
  if word.length() == 0 {
    return
  }
  let width = measure_text_width(word, size)
  if flow.x + width > flow.max_x && flow.x > flow.x0 {
    self.next_table_line(flow)
  }
  if width <= flow.max_x - flow.x0 {
    self.add_table_text(flow, word, size, color, weight)
  } else {
    for character in word.split("") {
      let piece = character.to_owned()
      let piece_w = measure_text_width(piece, size)
      if flow.x + piece_w > flow.max_x && flow.x > flow.x0 {
        self.next_table_line(flow)
      }
      let available = flow.max_x - flow.x0
      let fitted_size = if piece_w > available {
        size * available / piece_w * 0.999
      } else {
        size
      }
      self.add_table_text(flow, piece, fitted_size, color, weight)
    }
  }
}

///|
fn LayoutEngine::layout_table_inline(
  self : LayoutEngine,
  flow : TableCellFlow,
  inline : @core.Inline,
  size : Double,
  color : String,
  weight : String,
) -> Unit {
  match inline {
    @core.Inline::Text(text) => {
      let mut first = true
      for word in text.split(" ") {
        if !first && flow.x > flow.x0 {
          let space_w = measure_text_width(" ", size)
          if flow.x + space_w <= flow.max_x {
            self.add_table_text(flow, " ", size, color, weight)
          } else {
            self.next_table_line(flow)
          }
        }
        self.layout_table_word(flow, word.to_owned(), size, color, weight)
        first = false
      }
    }
    @core.Inline::Bold(inners) =>
      for inner in inners {
        self.layout_table_inline(flow, inner, size, color, "bold")
      }
    @core.Inline::Italic(inners) =>
      for inner in inners {
        self.layout_table_inline(flow, inner, size, color, "italic")
      }
    @core.Inline::Code(code) =>
      self.layout_table_word(flow, code, size * 0.9, "#d73a49", "monospace")
    @core.Inline::Link(url, text) => {
      let display = if text.length() > 0 { text } else { url }
      self.layout_table_word(flow, display, size, "#0969da", weight)
    }
    @core.Inline::FootnoteRef(idx) =>
      self.layout_table_word(flow, "[\{idx}]", size * 0.75, "#0969da", "bold")
    @core.Inline::StyledSpan(inners, custom_color, custom_size) => {
      let use_color = match custom_color {
        Some(c) => c.to_hex()
        None => color
      }
      let use_size = match custom_size {
        Some(s) => s
        None => size
      }
      for inner in inners {
        self.layout_table_inline(flow, inner, use_size, use_color, weight)
      }
    }
    @core.Inline::LineBreak => self.next_table_line(flow)
    @core.Inline::InlineMath(expr) =>
      self.layout_table_math(flow, expr, size, color)
  }
}

///|
fn LayoutEngine::layout_table_math(
  self : LayoutEngine,
  flow : TableCellFlow,
  expr : @core.MathExpr,
  size : Double,
  color : String,
) -> Unit {
  let probe = LayoutEngine::new(self.ctx)
  probe.cur_x = 0.0
  probe.cur_y = 0.0
  probe.layout_inline_math(expr, size)
  if probe.boxes.length() == 0 {
    return
  }
  let mut min_x = probe.boxes[0].rect.x
  let mut min_y = probe.boxes[0].rect.y
  let mut max_x = probe.boxes[0].rect.x + probe.boxes[0].rect.w
  let mut max_y = probe.boxes[0].rect.y + probe.boxes[0].rect.h
  for box in probe.boxes {
    let rect = box.rect
    if rect.x < min_x {
      min_x = rect.x
    }
    if rect.y < min_y {
      min_y = rect.y
    }
    if rect.x + rect.w > max_x {
      max_x = rect.x + rect.w
    }
    if rect.y + rect.h > max_y {
      max_y = rect.y + rect.h
    }
  }
  let advance = if probe.cur_x > max_x {
    probe.cur_x - min_x
  } else {
    max_x - min_x
  }
  if advance > flow.max_x - flow.x0 {
    self.layout_table_inline(
      flow,
      @core.Inline::Text(table_math_text(expr)),
      size,
      color,
      "italic",
    )
    return
  }
  if flow.x + advance > flow.max_x && flow.x > flow.x0 {
    self.next_table_line(flow)
  }
  let dx = flow.x - min_x
  let dy = flow.y - min_y
  for box in probe.boxes {
    self.boxes.push(translate_table_box(box, dx, dy))
  }
  flow.x = flow.x + advance
  if max_y + dy > flow.bottom {
    flow.bottom = max_y + dy
  }
  if max_y + dy > flow.line_bottom {
    flow.line_bottom = max_y + dy
  }
}

///|
fn table_math_text(expr : @core.MathExpr) -> String {
  match expr {
    @core.MathExpr::Sym(s) => s
    @core.MathExpr::Op(op) => " \{op} "
    @core.MathExpr::Frac(num, den) =>
      "(\{table_math_text(num)})/(\{table_math_text(den)})"
    @core.MathExpr::Sqrt(inner) => "√(\{table_math_text(inner)})"
    @core.MathExpr::Group(items) => {
      let builder = StringBuilder()
      for item in items {
        builder.write_string(table_math_text(item))
      }
      builder.to_string()
    }
    @core.MathExpr::SubSup(base, sub, sup) => {
      let builder = StringBuilder()
      builder.write_string(table_math_text(base))
      match sub {
        Some(value) => builder.write_string("_\{table_math_text(value)}")
        None => ()
      }
      match sup {
        Some(value) => builder.write_string("^\{table_math_text(value)}")
        None => ()
      }
      builder.to_string()
    }
    @core.MathExpr::Matrix(rows, cols, elems) => {
      let builder = StringBuilder()
      builder.write_string("matrix(\{rows}x\{cols}: [[")
      for i, elem in elems {
        if i > 0 {
          if cols > 0 && i % cols == 0 {
            builder.write_string("], [")
          } else {
            builder.write_string(", ")
          }
        }
        builder.write_string(table_math_text(elem))
      }
      builder.write_string("]])")
      builder.to_string()
    }
    @core.MathExpr::Vec(elems) => {
      let builder = StringBuilder()
      builder.write_string("[")
      for i, elem in elems {
        if i > 0 {
          builder.write_string(", ")
        }
        builder.write_string(table_math_text(elem))
      }
      builder.write_string("]")
      builder.to_string()
    }
    @core.MathExpr::Accent(inner, acc) => "\{acc}(\{table_math_text(inner)})"
    @core.MathExpr::Limits(op, lower, upper) => {
      let builder = StringBuilder()
      builder.write_string(table_math_text(op))
      match lower {
        Some(value) => builder.write_string("_\{table_math_text(value)}")
        None => ()
      }
      match upper {
        Some(value) => builder.write_string("^\{table_math_text(value)}")
        None => ()
      }
      builder.to_string()
    }
  }
}

///|
fn LayoutEngine::layout_shape(
  self : LayoutEngine,
  shape : @core.ShapeKind,
  style : @core.ShapeStyle,
) -> Unit {
  let fill_hex = match style.fill {
    Some(c) => c.to_hex()
    None => ""
  }
  let stroke_hex = match style.stroke {
    Some(c) => c.to_hex()
    None => ""
  }
  let stroke_w = style.stroke_width

  match shape {
    @core.ShapeKind::Rect(w_len, h_len, radius) => {
      let w = w_len.to_pt(self.ctx.font_size, self.ctx.content_width())
      let h = h_len.to_pt(self.ctx.font_size, self.ctx.content_width())
      if fill_hex.length() > 0 {
        let fill_box = LayoutBox::new(
          Rect::new(self.cur_x, self.cur_y, w, h),
          BoxKind::RectFill(w, h, fill_hex, radius),
        )
        self.boxes.push(fill_box)
      }
      if stroke_hex.length() > 0 {
        let stroke_box = LayoutBox::new(
          Rect::new(self.cur_x, self.cur_y, w, h),
          BoxKind::RectStroke(w, h, stroke_hex, stroke_w),
        )
        self.boxes.push(stroke_box)
      }
      self.cur_y = self.cur_y + h + 12.0
    }
    @core.ShapeKind::Circle(r_len) => {
      let r = r_len.to_pt(self.ctx.font_size, self.ctx.content_width())
      let circle_box = LayoutBox::new(
        Rect::new(self.cur_x, self.cur_y, r * 2.0, r * 2.0),
        BoxKind::Circle(r, fill_hex, stroke_hex, stroke_w),
      )
      self.boxes.push(circle_box)
      self.cur_y = self.cur_y + r * 2.0 + 12.0
    }
    @core.ShapeKind::Line(x1_l, y1_l, x2_l, y2_l) => {
      let x1 = self.cur_x +
        x1_l.to_pt(self.ctx.font_size, self.ctx.content_width())
      let y1 = self.cur_y +
        y1_l.to_pt(self.ctx.font_size, self.ctx.content_width())
      let x2 = self.cur_x +
        x2_l.to_pt(self.ctx.font_size, self.ctx.content_width())
      let y2 = self.cur_y +
        y2_l.to_pt(self.ctx.font_size, self.ctx.content_width())
      let line_box = LayoutBox::new(
        Rect::new(x1, y1, x2 - x1, y2 - y1),
        BoxKind::Line(x1, y1, x2, y2, stroke_hex, stroke_w),
      )
      self.boxes.push(line_box)
      self.cur_y = self.cur_y + 16.0
    }
    @core.ShapeKind::Polygon(_) => ()
  }
}

///|
fn LayoutEngine::layout_grid(
  self : LayoutEngine,
  cols : Array[@core.Length],
  items : Array[@core.Block],
) -> Unit {
  self.cur_y = self.cur_y + 12.0
  let num_cols = if cols.length() > 0 { cols.length() } else { 1 }
  let total_w = self.ctx.content_width()
  let col_w = total_w / num_cols.to_double()

  for i, item in items {
    let col_idx = i % num_cols
    let item_x = self.ctx.margin_x + col_idx.to_double() * col_w
    let orig_x = self.cur_x
    self.cur_x = item_x
    self.layout_block(item)
    self.cur_x = orig_x
  }
  self.cur_y = self.cur_y + 16.0
  self.cur_x = self.ctx.margin_x
}

///|
fn LayoutEngine::layout_footnote_block(
  self : LayoutEngine,
  index : Int,
  inlines : Array[@core.Inline],
) -> Unit {
  self.cur_y = self.cur_y + 8.0
  let num_str = "[\{index}] "
  let fn_size = self.ctx.font_size * 0.8
  let w = measure_text_width(num_str, fn_size)
  let b = LayoutBox::new(
    Rect::new(self.cur_x, self.cur_y, w, fn_size),
    BoxKind::Text(num_str, fn_size, "#57606a", "bold"),
  )
  self.boxes.push(b)
  self.cur_x = self.cur_x + w

  for inline in inlines {
    self.layout_inline_styled(inline, fn_size, "#57606a", "normal")
  }
  self.cur_y = self.cur_y + fn_size * 1.4 + 4.0
  self.cur_x = self.ctx.margin_x
}

///|
fn LayoutEngine::layout_figure(
  self : LayoutEngine,
  body : @core.Block,
  caption : Array[@core.Inline]?,
) -> Unit {
  self.cur_y = self.cur_y + 12.0
  self.layout_block(body)
  match caption {
    Some(inlines) => {
      self.cur_y = self.cur_y + 4.0
      self.cur_x = self.ctx.margin_x + 24.0
      let caption_size = self.ctx.font_size * 0.85
      let label_box = LayoutBox::new(
        Rect::new(self.cur_x, self.cur_y, 48.0, caption_size),
        BoxKind::Text("Figure: ", caption_size, "#57606a", "bold"),
      )
      self.boxes.push(label_box)
      self.cur_x = self.cur_x + 50.0

      for inline in inlines {
        self.layout_inline_styled(inline, caption_size, "#57606a", "italic")
      }
      self.cur_y = self.cur_y + caption_size * 1.5 + 8.0
      self.cur_x = self.ctx.margin_x
    }
    None => ()
  }
}

///|
fn LayoutEngine::layout_align_block(
  self : LayoutEngine,
  align : @core.TextAlign,
  body : @core.Block,
) -> Unit {
  let orig_x = self.cur_x
  match align {
    @core.TextAlign::Center => self.cur_x = self.ctx.margin_x + 48.0
    @core.TextAlign::Right => self.cur_x = self.ctx.margin_x + 96.0
    _ => ()
  }
  self.layout_block(body)
  self.cur_x = orig_x
}

///|
fn LayoutEngine::layout_page_break(self : LayoutEngine) -> Unit {
  self.cur_y = self.cur_y + 24.0
  let b = LayoutBox::new(
    Rect::new(self.ctx.margin_x, self.cur_y, self.ctx.content_width(), 1.0),
    BoxKind::Line(
      self.ctx.margin_x,
      self.cur_y,
      self.ctx.margin_x + self.ctx.content_width(),
      self.cur_y,
      "#d0d7de",
      1.0,
    ),
  )
  self.boxes.push(b)
  self.cur_y = self.cur_y + 24.0
  self.cur_x = self.ctx.margin_x
}

///|
fn LayoutEngine::layout_matrix(
  self : LayoutEngine,
  rows : Int,
  cols : Int,
  elems : Array[@core.MathExpr],
  font_size : Double,
) -> Unit {
  let cell_w = font_size * 1.8
  let cell_h = font_size * 1.4
  let total_w = cols.to_double() * cell_w + 12.0
  let total_h = rows.to_double() * cell_h

  // Left bracket [
  let lb = LayoutBox::new(
    Rect::new(self.cur_x, self.cur_y, 4.0, total_h),
    BoxKind::Line(
      self.cur_x,
      self.cur_y,
      self.cur_x,
      self.cur_y + total_h,
      "#24292f",
      1.5,
    ),
  )
  self.boxes.push(lb)

  // Layout matrix elements
  for r = 0; r < rows; r = r + 1 {
    for c = 0; c < cols; c = c + 1 {
      let idx = r * cols + c
      if idx < elems.length() {
        let old_x = self.cur_x
        let old_y = self.cur_y
        self.cur_x = old_x + 6.0 + c.to_double() * cell_w
        self.cur_y = old_y + r.to_double() * cell_h
        self.layout_inline_math(elems[idx], font_size * 0.9)
        self.cur_x = old_x
        self.cur_y = old_y
      }
    }
  }

  // Right bracket ]
  let rb_x = self.cur_x + total_w
  let rb = LayoutBox::new(
    Rect::new(rb_x, self.cur_y, 4.0, total_h),
    BoxKind::Line(rb_x, self.cur_y, rb_x, self.cur_y + total_h, "#24292f", 1.5),
  )
  self.boxes.push(rb)
  self.cur_x = rb_x + 8.0
}

///|
fn LayoutEngine::layout_accent(
  self : LayoutEngine,
  inner : @core.MathExpr,
  acc : String,
  font_size : Double,
) -> Unit {
  let mark = match acc {
    "hat" => "^"
    "tilde" => "~"
    "bar" => "-"
    "dot" => "."
    "vec" => "->"
    _ => "^"
  }
  let old_y = self.cur_y
  let old_x = self.cur_x
  // Place accent above
  self.cur_y = self.cur_y - font_size * 0.4
  let mark_box = LayoutBox::new(
    Rect::new(self.cur_x + 2.0, self.cur_y, font_size * 0.5, font_size * 0.5),
    BoxKind::Text(mark, font_size * 0.7, "#24292f", "normal"),
  )
  self.boxes.push(mark_box)
  self.cur_y = old_y
  self.cur_x = old_x
  self.layout_inline_math(inner, font_size)
}

///|
fn LayoutEngine::layout_limits(
  self : LayoutEngine,
  op : @core.MathExpr,
  lower : @core.MathExpr?,
  upper : @core.MathExpr?,
  font_size : Double,
) -> Unit {
  let old_y = self.cur_y
  let old_x = self.cur_x

  // Upper limit above op
  match upper {
    Some(up) => {
      self.cur_y = self.cur_y - font_size * 0.45
      self.layout_inline_math(up, font_size * 0.65)
      self.cur_y = old_y
      self.cur_x = old_x
    }
    None => ()
  }

  // Operator
  self.layout_inline_math(op, font_size * 1.1)

  // Lower limit below op
  match lower {
    Some(low) => {
      let low_x = old_x
      let low_y = self.cur_y + font_size * 0.45
      let saved_x = self.cur_x
      self.cur_x = low_x
      self.cur_y = low_y
      self.layout_inline_math(low, font_size * 0.65)
      self.cur_y = old_y
      self.cur_x = saved_x
    }
    None => ()
  }
}
