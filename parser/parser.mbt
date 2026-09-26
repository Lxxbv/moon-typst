///|
/// Recursive descent parser for Typst document markup
pub struct Parser {
  tokens : Array[Token]
  len : Int
  mut pos : Int
}

///|
pub fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, len: tokens.length(), pos: 0, }
}

///|
fn Parser::peek(self : Parser) -> Token {
  if self.pos < self.len {
    self.tokens[self.pos]
  } else {
    Token::Eof
  }
}

///|
fn Parser::peek_at(self : Parser, offset : Int) -> Token {
  let idx = self.pos + offset
  if idx < self.len {
    self.tokens[idx]
  } else {
    Token::Eof
  }
}

///|
fn Parser::advance(self : Parser) -> Token {
  let t = self.peek()
  self.pos = self.pos + 1
  t
}

///|
fn Parser::skip_newlines(self : Parser) -> Unit {
  while self.pos < self.len {
    match self.peek() {
      Token::Newline => {
        let _ = self.advance()
      }
      _ => break
    }
  }
}

///|
/// High-level function to parse a Typst source string into a Doc AST
pub fn parse_typst(source : String) -> @core.Doc {
  let lexer = Lexer::new(source)
  let tokens = lexer.tokenize()
  let parser = Parser::new(tokens)
  parser.parse()
}

///|
/// Main document parsing entrypoint
pub fn Parser::parse(self : Parser) -> @core.Doc {
  let doc = @core.Doc::new()
  self.skip_newlines()
  while self.pos < self.len {
    match self.peek() {
      Token::Eof => break
      Token::Newline => {
        let _ = self.advance()
      }
      Token::HeadingPrefix(level) => {
        let _ = self.advance()
        let inlines = self.parse_line_inlines()
        doc.add_block(@core.Block::Heading(level, inlines))
        self.skip_newlines()
      }
      Token::HorizontalRule => {
        let _ = self.advance()
        doc.add_block(@core.Block::HorizontalRule)
        self.skip_newlines()
      }
      Token::RawBlock(lang, code) => {
        let _ = self.advance()
        doc.add_block(@core.Block::CodeBlock(lang, code))
        self.skip_newlines()
      }
      Token::DashItem => {
        let items : Array[Array[@core.Inline]] = []
        while self.pos < self.len {
          match self.peek() {
            Token::DashItem => {
              let _ = self.advance()
              let inlines = self.parse_line_inlines()
              items.push(inlines)
              // If followed by single newline and another DashItem, continue
              if self.peek() == Token::Newline &&
                self.peek_at(1) == Token::DashItem {
                let _ = self.advance()
              } else {
                break
              }
            }
            _ => break
          }
        }
        doc.add_block(@core.Block::List(false, items))
        self.skip_newlines()
      }
      Token::PlusItem => {
        let items : Array[Array[@core.Inline]] = []
        while self.pos < self.len {
          match self.peek() {
            Token::PlusItem => {
              let _ = self.advance()
              let inlines = self.parse_line_inlines()
              items.push(inlines)
              if self.peek() == Token::Newline &&
                self.peek_at(1) == Token::PlusItem {
                let _ = self.advance()
              } else {
                break
              }
            }
            _ => break
          }
        }
        doc.add_block(@core.Block::List(true, items))
        self.skip_newlines()
      }
      Token::Bar => {
        let table = self.parse_table()
        doc.add_block(table)
        self.skip_newlines()
      }
      // Check for standalone math block on line: $ math $
      Token::Dollar =>
        if self.line_has_pipe(self.pos) {
          doc.add_block(self.parse_table())
          self.skip_newlines()
        } else {
          // If it looks like a block formula
          let block_opt = self.try_parse_math_block()
          match block_opt {
            Some(block) => {
              doc.add_block(block)
              self.skip_newlines()
            }
            None => {
              let p = self.parse_paragraph()
              doc.add_block(p)
              self.skip_newlines()
            }
          }
        }
      Token::HashIdent(name) => {
        let _ = self.advance()
        if name == "pagebreak" {
          if self.peek() == Token::LParen {
            let _ = self.advance()
            if self.peek() == Token::RParen {
              let _ = self.advance()
            }
          }
          doc.add_block(@core.Block::PageBreak)
          self.skip_newlines()
        } else if name == "rect" {
          doc.add_block(
            @core.Block::Shape(
              @core.ShapeKind::Rect(
                @core.Length::Pt(120.0),
                @core.Length::Pt(60.0),
                4.0,
              ),
              @core.ShapeStyle::default(),
            ),
          )
          self.skip_newlines()
        } else if name == "circle" {
          doc.add_block(
            @core.Block::Shape(
              @core.ShapeKind::Circle(@core.Length::Pt(30.0)),
              @core.ShapeStyle::default(),
            ),
          )
          self.skip_newlines()
        } else if name == "grid" {
          doc.add_block(
            @core.Block::Grid([@core.Length::Fr(1.0), @core.Length::Fr(1.0)], []),
          )
          self.skip_newlines()
        } else {
          self.skip_newlines()
        }
      }
      _ => {
        if self.line_has_pipe(self.pos) {
          doc.add_block(self.parse_table())
        } else {
          doc.add_block(self.parse_paragraph())
        }
        self.skip_newlines()
      }
    }
  }
  doc
}

///|
fn Parser::parse_line_inlines(self : Parser) -> Array[@core.Inline] {
  let inlines : Array[@core.Inline] = []
  while self.pos < self.len {
    match self.peek() {
      Token::Eof | Token::Newline => break
      _ => {
        let item = self.parse_single_inline()
        inlines.push(item)
      }
    }
  }
  inlines
}

///|
fn Parser::parse_single_inline(self : Parser) -> @core.Inline {
  match self.peek() {
    Token::Star => {
      let _ = self.advance()
      let inners : Array[@core.Inline] = []
      while self.pos < self.len {
        match self.peek() {
          Token::Star => {
            let _ = self.advance()
            break
          }
          Token::Eof | Token::Newline => break
          _ => inners.push(self.parse_single_inline())
        }
      }
      @core.Inline::Bold(inners)
    }
    Token::Underscore => {
      let _ = self.advance()
      let inners : Array[@core.Inline] = []
      while self.pos < self.len {
        match self.peek() {
          Token::Underscore => {
            let _ = self.advance()
            break
          }
          Token::Eof | Token::Newline => break
          _ => inners.push(self.parse_single_inline())
        }
      }
      @core.Inline::Italic(inners)
    }
    Token::InlineCode(code) => {
      let _ = self.advance()
      @core.Inline::Code(code)
    }
    Token::Dollar => {
      let _ = self.advance()
      let math_expr = self.parse_math_expression()
      if self.peek() == Token::Dollar {
        let _ = self.advance()
      }
      @core.Inline::InlineMath(math_expr)
    }
    Token::Text(s) => {
      let _ = self.advance()
      @core.Inline::Text(s)
    }
    Token::Slash => {
      let _ = self.advance()
      @core.Inline::Text("/")
    }
    Token::Bar => {
      let _ = self.advance()
      @core.Inline::Text("|")
    }
    Token::LParen => {
      let _ = self.advance()
      @core.Inline::Text("(")
    }
    Token::RParen => {
      let _ = self.advance()
      @core.Inline::Text(")")
    }
    Token::LBracket => {
      let _ = self.advance()
      @core.Inline::Text("[")
    }
    Token::RBracket => {
      let _ = self.advance()
      @core.Inline::Text("]")
    }
    _ => {
      let _ = self.advance()
      @core.Inline::Text(" ")
    }
  }
}

///|
fn Parser::parse_paragraph(self : Parser) -> @core.Block {
  let inlines : Array[@core.Inline] = []
  while self.pos < self.len {
    match self.peek() {
      Token::Eof => break
      Token::Newline => {
        // Double newline ends paragraph
        if self.peek_at(1) == Token::Newline || self.peek_at(1) == Token::Eof {
          break
        }
        // Next line might be a block element (Heading, List, CodeBlock, etc.)
        match self.peek_at(1) {
          Token::HeadingPrefix(_)
          | Token::DashItem
          | Token::PlusItem
          | Token::HorizontalRule
          | Token::RawBlock(_, _) => break
          _ => {
            if self.line_has_pipe(self.pos + 1) {
              break
            }
            let _ = self.advance()
            inlines.push(@core.Inline::Text(" "))
          }
        }
      }
      _ => {
        let item = self.parse_single_inline()
        inlines.push(item)
      }
    }
  }
  @core.Block::Paragraph(inlines)
}

///|
fn Parser::try_parse_math_block(self : Parser) -> @core.Block? {
  // If current token is Dollar, check if this line is a standalone math block
  // Save position for backtracking
  let saved_pos = self.pos
  let _ = self.advance() // consume initial Dollar
  let math_expr = self.parse_math_expression()
  if self.peek() == Token::Dollar {
    let _ = self.advance()
    if self.peek() == Token::Newline || self.peek() == Token::Eof {
      return Some(@core.Block::MathBlock(math_expr))
    }
  }
  // Backtrack if not a block
  self.pos = saved_pos
  None
}

///|
fn Parser::parse_math_expression(self : Parser) -> @core.MathExpr {
  let items : Array[@core.MathExpr] = []
  while self.pos < self.len {
    match self.peek() {
      Token::Dollar | Token::Eof | Token::Newline => break
      Token::Slash => {
        let _ = self.advance()
        items.push(@core.MathExpr::Op("/"))
      }
      Token::Text(s) => {
        let _ = self.advance()
        let words = split_math_tokens(s)
        for w in words {
          if w == "+" ||
            w == "-" ||
            w == "*" ||
            w == "=" ||
            w == "<" ||
            w == ">" ||
            w == "^" {
            items.push(@core.MathExpr::Op(w))
          } else if w.has_prefix("sqrt(") && w.has_suffix(")") {
            let inner = w[5:w.length() - 1].to_owned()
            items.push(@core.MathExpr::Sqrt(@core.MathExpr::Sym(inner)))
          } else {
            items.push(@core.MathExpr::Sym(w))
          }
        }
      }
      _ => {
        let atom = self.parse_math_atom()
        items.push(atom)
      }
    }
  }
  let mut i = 0
  let resolved : Array[@core.MathExpr] = []
  while i < items.length() {
    if i + 2 < items.length() {
      match items[i + 1] {
        @core.MathExpr::Op("/") => {
          let frac = @core.MathExpr::Frac(items[i], items[i + 2])
          resolved.push(frac)
          i = i + 3
          continue
        }
        _ => ()
      }
    }
    if i + 1 < items.length() {
      match (items[i], items[i + 1]) {
        (@core.MathExpr::Sym("sqrt"), @core.MathExpr::Group(inner_items)) => {
          let inner = if inner_items.length() == 1 {
            inner_items[0]
          } else {
            @core.MathExpr::Group(inner_items)
          }
          resolved.push(@core.MathExpr::Sqrt(inner))
          i = i + 2
          continue
        }
        (@core.MathExpr::Sym("hat"), @core.MathExpr::Group(inner_items)) => {
          let inner = if inner_items.length() == 1 {
            inner_items[0]
          } else {
            @core.MathExpr::Group(inner_items)
          }
          resolved.push(@core.MathExpr::Accent(inner, "hat"))
          i = i + 2
          continue
        }
        (@core.MathExpr::Sym("tilde"), @core.MathExpr::Group(inner_items)) => {
          let inner = if inner_items.length() == 1 {
            inner_items[0]
          } else {
            @core.MathExpr::Group(inner_items)
          }
          resolved.push(@core.MathExpr::Accent(inner, "tilde"))
          i = i + 2
          continue
        }
        (@core.MathExpr::Sym("bar"), @core.MathExpr::Group(inner_items)) => {
          let inner = if inner_items.length() == 1 {
            inner_items[0]
          } else {
            @core.MathExpr::Group(inner_items)
          }
          resolved.push(@core.MathExpr::Accent(inner, "bar"))
          i = i + 2
          continue
        }
        (@core.MathExpr::Sym("dot"), @core.MathExpr::Group(inner_items)) => {
          let inner = if inner_items.length() == 1 {
            inner_items[0]
          } else {
            @core.MathExpr::Group(inner_items)
          }
          resolved.push(@core.MathExpr::Accent(inner, "dot"))
          i = i + 2
          continue
        }
        (@core.MathExpr::Sym("vec"), @core.MathExpr::Group(inner_items)) => {
          let vec_elems : Array[@core.MathExpr] = []
          for item in inner_items {
            match item {
              @core.MathExpr::Op(",") => ()
              _ => vec_elems.push(item)
            }
          }
          resolved.push(@core.MathExpr::Vec(vec_elems))
          i = i + 2
          continue
        }
        (@core.MathExpr::Sym("mat"), @core.MathExpr::Group(inner_items)) => {
          let mut rows = 1
          let mut cols_in_row = 0
          let mut max_cols = 0
          let mat_elems : Array[@core.MathExpr] = []
          for item in inner_items {
            match item {
              @core.MathExpr::Op(";") => {
                rows = rows + 1
                if cols_in_row > max_cols {
                  max_cols = cols_in_row
                }
                cols_in_row = 0
              }
              @core.MathExpr::Op(",") => ()
              _ => {
                mat_elems.push(item)
                cols_in_row = cols_in_row + 1
              }
            }
          }
          if cols_in_row > max_cols {
            max_cols = cols_in_row
          }
          let final_cols = if max_cols > 0 { max_cols } else { 1 }
          resolved.push(@core.MathExpr::Matrix(rows, final_cols, mat_elems))
          i = i + 2
          continue
        }
        _ => ()
      }
    }
    resolved.push(items[i])
    i = i + 1
  }
  if resolved.length() == 0 {
    @core.MathExpr::Sym("")
  } else if resolved.length() == 1 {
    resolved[0]
  } else {
    @core.MathExpr::Group(resolved)
  }
}

///|
fn Parser::parse_math_atom(self : Parser) -> @core.MathExpr {
  match self.peek() {
    Token::Equal => {
      let _ = self.advance()
      @core.MathExpr::Op("=")
    }
    Token::Comma => {
      let _ = self.advance()
      @core.MathExpr::Op(",")
    }
    Token::Semicolon => {
      let _ = self.advance()
      @core.MathExpr::Op(";")
    }
    Token::Text(s) => {
      let _ = self.advance()
      let trimmed = s.trim().to_owned()
      if (
          trimmed == "mat" ||
          trimmed == "vec" ||
          trimmed == "hat" ||
          trimmed == "tilde" ||
          trimmed == "bar" ||
          trimmed == "dot" ||
          trimmed == "sqrt"
        ) &&
        self.peek() == Token::LParen {
        let _ = self.advance() // consume LParen
        if trimmed == "mat" {
          self.parse_matrix_paren_content()
        } else if trimmed == "vec" {
          self.parse_vec_paren_content()
        } else if trimmed == "sqrt" {
          let inner = self.parse_math_expression()
          if self.peek() == Token::RParen {
            let _ = self.advance()
          }
          @core.MathExpr::Sqrt(inner)
        } else {
          let inner = self.parse_math_expression()
          if self.peek() == Token::RParen {
            let _ = self.advance()
          }
          @core.MathExpr::Accent(inner, trimmed)
        }
      } else if trimmed == "+" ||
        trimmed == "-" ||
        trimmed == "*" ||
        trimmed == "=" ||
        trimmed == "<" ||
        trimmed == ">" ||
        trimmed == "!=" ||
        trimmed == "<=" ||
        trimmed == ">=" {
        @core.MathExpr::Op(trimmed)
      } else {
        @core.MathExpr::Sym(trimmed)
      }
    }
    Token::LParen => {
      let _ = self.advance()
      let mut depth = 1
      let inner_tokens : Array[Token] = []
      while self.pos < self.len {
        match self.peek() {
          Token::LParen => {
            depth = depth + 1
            inner_tokens.push(self.advance())
          }
          Token::RParen => {
            depth = depth - 1
            if depth == 0 {
              let _ = self.advance()
              break
            } else {
              inner_tokens.push(self.advance())
            }
          }
          Token::Dollar | Token::Eof => break
          _ => inner_tokens.push(self.advance())
        }
      }
      let sub_parser = Parser::new(inner_tokens)
      let parsed = sub_parser.parse_math_expression()
      match parsed {
        @core.MathExpr::Group(_) => parsed
        _ => @core.MathExpr::Group([parsed])
      }
    }
    _ => {
      let _ = self.advance()
      @core.MathExpr::Sym("")
    }
  }
}

///|
fn Parser::parse_table(self : Parser) -> @core.Block {
  let rows : Array[Array[Array[@core.Inline]]] = []
  let mut separator : Array[@core.TableAlignment]? = None
  let mut max_cols = 0
  while self.line_has_pipe(self.pos) {
    let row = self.parse_table_row()
    if rows.length() == 1 &&
      separator is None &&
      row.length() == rows[0].length() {
      match table_separator_alignments(row) {
        Some(alignments) => {
          separator = Some(alignments)
          continue
        }
        None => ()
      }
    }
    if row.length() > max_cols {
      max_cols = row.length()
    }
    rows.push(row)
  }
  match separator {
    Some(alignments) =>
      if alignments.length() > max_cols {
        max_cols = alignments.length()
      }
    None => ()
  }
  let alignments : Array[@core.TableAlignment] = []
  for i = 0; i < max_cols; i = i + 1 {
    match separator {
      Some(markers) if i < markers.length() => alignments.push(markers[i])
      _ => alignments.push(@core.TableAlignment::Left)
    }
  }
  for row in rows {
    while row.length() < max_cols {
      row.push([])
    }
  }
  @core.Block::Table({
    rows,
    header_rows: if separator is Some(_) {
      1
    } else {
      0
    },
    alignments,
  })
}

///|
fn Parser::line_has_pipe(self : Parser, start : Int) -> Bool {
  let mut i = start
  while i < self.len {
    match self.tokens[i] {
      Token::Bar => return true
      Token::Newline | Token::Eof => return false
      Token::Dollar | Token::Star | Token::Underscore => {
        let marker = self.tokens[i]
        let mut end = i + 1
        while end < self.len {
          match self.tokens[end] {
            Token::Newline | Token::Eof => break
            token if token == marker => break
            _ => end = end + 1
          }
        }
        if end < self.len && self.tokens[end] == marker {
          i = end + 1
        } else {
          i = i + 1
        }
      }
      _ => i = i + 1
    }
  }
  false
}

///|
fn Parser::parse_table_row(self : Parser) -> Array[Array[@core.Inline]] {
  let row : Array[Array[@core.Inline]] = []
  let mut cell : Array[@core.Inline] = []
  let mut first = true
  let mut ended_with_bar = false
  while self.pos < self.len {
    match self.peek() {
      Token::Newline | Token::Eof => break
      Token::Bar => {
        let _ = self.advance()
        if first {
          first = false
        } else {
          row.push(trim_table_cell(cell))
        }
        cell = []
        ended_with_bar = true
      }
      Token::Colon => {
        let _ = self.advance()
        cell.push(@core.Inline::Text(":"))
        first = false
        ended_with_bar = false
      }
      Token::HorizontalRule => {
        let _ = self.advance()
        cell.push(@core.Inline::Text("---"))
        first = false
        ended_with_bar = false
      }
      Token::Text(s) if ended_with_bar &&
        s.trim().length() == 0 &&
        (self.peek_at(1) == Token::Newline || self.peek_at(1) == Token::Eof) => {
        let _ = self.advance()
      }
      _ => {
        cell.push(self.parse_single_inline())
        first = false
        ended_with_bar = false
      }
    }
  }
  if !ended_with_bar || row.length() == 0 {
    row.push(trim_table_cell(cell))
  }
  if self.peek() == Token::Newline {
    let _ = self.advance()
  }
  row
}

///|
fn trim_table_cell(cell : Array[@core.Inline]) -> Array[@core.Inline] {
  let result : Array[@core.Inline] = []
  for i, inline in cell {
    match inline {
      @core.Inline::Text(s) if i == 0 || i == cell.length() - 1 => {
        let trimmed = if i == 0 && i == cell.length() - 1 {
          s.trim().to_owned()
        } else if i == 0 {
          s.trim_start().to_owned()
        } else {
          s.trim_end().to_owned()
        }
        if trimmed.length() > 0 {
          result.push(@core.Inline::Text(trimmed))
        }
      }
      _ => result.push(inline)
    }
  }
  result
}

///|
fn table_separator_alignments(
  row : Array[Array[@core.Inline]],
) -> Array[@core.TableAlignment]? {
  let alignments : Array[@core.TableAlignment] = []
  for cell in row {
    let builder = StringBuilder()
    for inline in cell {
      match inline {
        @core.Inline::Text(s) => builder.write_string(s)
        _ => return None
      }
    }
    let marker = builder.to_string().trim().to_owned()
    if marker.length() == 0 {
      return None
    }
    let left = marker[0] == ':'
    let right = marker[marker.length() - 1] == ':'
    let start = if left { 1 } else { 0 }
    let stop = if right { marker.length() - 1 } else { marker.length() }
    if stop <= start {
      return None
    }
    for i = start; i < stop; i = i + 1 {
      if marker[i] != '-' {
        return None
      }
    }
    alignments.push(
      if left && right {
        @core.TableAlignment::Center
      } else if right {
        @core.TableAlignment::Right
      } else {
        @core.TableAlignment::Left
      },
    )
  }
  Some(alignments)
}

///|
fn Parser::parse_matrix_paren_content(self : Parser) -> @core.MathExpr {
  let elems : Array[@core.MathExpr] = []
  let mut row_count = 1
  let mut cols_in_cur_row = 0
  let mut max_cols = 0
  while self.pos < self.len {
    match self.peek() {
      Token::RParen | Token::Dollar | Token::Eof => {
        if self.peek() == Token::RParen {
          let _ = self.advance()
        }
        break
      }
      Token::Comma => {
        let _ = self.advance()
      }
      Token::Semicolon => {
        let _ = self.advance()
        row_count = row_count + 1
        if cols_in_cur_row > max_cols {
          max_cols = cols_in_cur_row
        }
        cols_in_cur_row = 0
      }
      _ => {
        let atom = self.parse_math_atom()
        elems.push(atom)
        cols_in_cur_row = cols_in_cur_row + 1
      }
    }
  }
  if cols_in_cur_row > max_cols {
    max_cols = cols_in_cur_row
  }
  let col_count = if max_cols > 0 { max_cols } else { 1 }
  @core.MathExpr::Matrix(row_count, col_count, elems)
}

///|
fn Parser::parse_vec_paren_content(self : Parser) -> @core.MathExpr {
  let elems : Array[@core.MathExpr] = []
  while self.pos < self.len {
    match self.peek() {
      Token::RParen | Token::Dollar | Token::Eof => {
        if self.peek() == Token::RParen {
          let _ = self.advance()
        }
        break
      }
      Token::Comma => {
        let _ = self.advance()
      }
      _ => {
        let atom = self.parse_math_atom()
        elems.push(atom)
      }
    }
  }
  @core.MathExpr::Vec(elems)
}
