///|
/// Recursive descent parser for Typst document markup

pub struct Parser {
  tokens : Array[Token]
  len : Int
  mut pos : Int
}

pub fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, len: tokens.length(), pos: 0 }
}

fn Parser::peek(self : Parser) -> Token {
  if self.pos < self.len {
    self.tokens[self.pos]
  } else {
    Token::Eof
  }
}

fn Parser::peek_at(self : Parser, offset : Int) -> Token {
  let idx = self.pos + offset
  if idx < self.len {
    self.tokens[idx]
  } else {
    Token::Eof
  }
}

fn Parser::advance(self : Parser) -> Token {
  let t = self.peek()
  self.pos = self.pos + 1
  t
}

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
              if self.peek() == Token::Newline && self.peek_at(1) == Token::DashItem {
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
              if self.peek() == Token::Newline && self.peek_at(1) == Token::PlusItem {
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
      Token::Dollar => {
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
      _ => {
        let p = self.parse_paragraph()
        doc.add_block(p)
        self.skip_newlines()
      }
    }
  }
  doc
}

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
          Token::HeadingPrefix(_) | Token::DashItem | Token::PlusItem | Token::HorizontalRule | Token::RawBlock(_, _) => break
          _ => {
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
          if w == "+" || w == "-" || w == "*" || w == "=" || w == "<" || w == ">" || w == "^" {
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

fn Parser::parse_math_atom(self : Parser) -> @core.MathExpr {
  match self.peek() {
    Token::Text(s) => {
      let _ = self.advance()
      let trimmed = s.trim().to_owned()
      if trimmed == "+" || trimmed == "-" || trimmed == "*" || trimmed == "=" ||
         trimmed == "<" || trimmed == ">" || trimmed == "!=" || trimmed == "<=" ||
         trimmed == ">=" {
        @core.MathExpr::Op(trimmed)
      } else if trimmed.has_prefix("sqrt(") && trimmed.has_suffix(")") {
        let inner_str = trimmed[5:trimmed.length() - 1].to_owned()
        @core.MathExpr::Sqrt(@core.MathExpr::Sym(inner_str))
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
      @core.MathExpr::Group([sub_parser.parse_math_expression()])
    }
    _ => {
      let _ = self.advance()
      @core.MathExpr::Sym("")
    }
  }
}

fn Parser::parse_table(self : Parser) -> @core.Block {
  let rows : Array[Array[@core.Inline]] = []
  let mut max_cols = 0
  while self.pos < self.len {
    if self.peek() != Token::Bar {
      break
    }
    let _ = self.advance() // consume starting |
    let mut cols_in_row = 0
    while self.pos < self.len {
      match self.peek() {
        Token::Newline | Token::Eof => {
          if self.peek() == Token::Newline {
            let _ = self.advance()
          }
          break
        }
        Token::Bar => {
          let _ = self.advance()
        }
        _ => {
          let inline = self.parse_single_inline()
          cols_in_row = cols_in_row + 1
          rows.push([inline])
        }
      }
    }
    if cols_in_row > max_cols {
      max_cols = cols_in_row
    }
  }
  @core.Block::Table(if max_cols == 0 { 1 } else { max_cols }, rows)
}
