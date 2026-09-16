///|
/// Typst Lexer implementation
pub struct Lexer {
  input : String
  len : Int
  mut pos : Int
  mut at_line_start : Bool
}

///|
pub fn Lexer::new(input : String) -> Lexer {
  { input, len: input.length(), pos: 0, at_line_start: true, }
}

///|
fn Lexer::peek(self : Lexer) -> Char {
  if self.pos < self.len {
    self.input[self.pos].to_int().unsafe_to_char()
  } else {
    '\u0000'
  }
}

///|
fn Lexer::peek_at(self : Lexer, offset : Int) -> Char {
  let idx = self.pos + offset
  if idx < self.len {
    self.input[idx].to_int().unsafe_to_char()
  } else {
    '\u0000'
  }
}

///|
fn Lexer::advance(self : Lexer) -> Char {
  let c = self.peek()
  self.pos = self.pos + 1
  c
}

///|
/// Tokenize entire input stream into an array of Tokens
pub fn Lexer::tokenize(self : Lexer) -> Array[Token] {
  let tokens : Array[Token] = []
  while self.pos < self.len {
    let c = self.peek()
    if c == '\r' || c == '\uFEFF' {
      let _ = self.advance()
      continue
    }
    if c == '\n' {
      let _ = self.advance()
      self.at_line_start = true
      tokens.push(Token::Newline)
      continue
    }

    // Skip horizontal spaces at start of line
    if self.at_line_start && (c == ' ' || c == '\t') {
      while self.pos < self.len && (self.peek() == ' ' || self.peek() == '\t') {
        let _ = self.advance()
      }
      continue
    }

    // Line-start specific tokens
    if self.at_line_start {
      // Heading: = , == , ===
      if c == '=' {
        let mut level = 0
        while self.pos < self.len && self.peek() == '=' {
          let _ = self.advance()
          level = level + 1
        }
        if self.pos < self.len && (self.peek() == ' ' || self.peek() == '\t') {
          while self.pos < self.len &&
                (self.peek() == ' ' || self.peek() == '\t') {
            let _ = self.advance()
          }
          self.at_line_start = false
          tokens.push(Token::HeadingPrefix(if level > 6 { 6 } else { level }))
          continue
        } else {
          let buf = StringBuilder()
          for i = 0; i < level; i = i + 1 {
            buf.write_char('=')
          }
          self.at_line_start = false
          tokens.push(Token::Text(buf.to_string()))
          continue
        }
      }

      // Horizontal Rule: ---
      if c == '-' && self.peek_at(1) == '-' && self.peek_at(2) == '-' {
        let _ = self.advance()
        let _ = self.advance()
        let _ = self.advance()
        while self.pos < self.len && (self.peek() == ' ' || self.peek() == '\t') {
          let _ = self.advance()
        }
        self.at_line_start = false
        tokens.push(Token::HorizontalRule)
        continue
      }

      // Unordered list item: - 
      if c == '-' && (self.peek_at(1) == ' ' || self.peek_at(1) == '\t') {
        let _ = self.advance()
        while self.pos < self.len && (self.peek() == ' ' || self.peek() == '\t') {
          let _ = self.advance()
        }
        self.at_line_start = false
        tokens.push(Token::DashItem)
        continue
      }

      // Ordered list item: + 
      if c == '+' && (self.peek_at(1) == ' ' || self.peek_at(1) == '\t') {
        let _ = self.advance()
        while self.pos < self.len && (self.peek() == ' ' || self.peek() == '\t') {
          let _ = self.advance()
        }
        self.at_line_start = false
        tokens.push(Token::PlusItem)
        continue
      }
    }

    // Code block: ```lang ... ```
    if c == '`' && self.peek_at(1) == '`' && self.peek_at(2) == '`' {
      let _ = self.advance()
      let _ = self.advance()
      let _ = self.advance()
      // Read language tag until newline
      let lang_buf = StringBuilder()
      while self.pos < self.len && self.peek() != '\n' && self.peek() != '\r' {
        lang_buf.write_char(self.advance())
      }
      if self.peek() == '\r' {
        let _ = self.advance()
      }
      if self.peek() == '\n' {
        let _ = self.advance()
      }
      // Read code content until closing ```
      let code_buf = StringBuilder()
      while self.pos < self.len {
        if self.peek() == '`' &&
          self.peek_at(1) == '`' &&
          self.peek_at(2) == '`' {
          let _ = self.advance()
          let _ = self.advance()
          let _ = self.advance()
          break
        }
        code_buf.write_char(self.advance())
      }
      self.at_line_start = false
      tokens.push(
        Token::RawBlock(
          lang_buf.to_string().trim().to_owned(),
          code_buf.to_string(),
        ),
      )
      continue
    }

    // Inline code: `code`
    if c == '`' {
      let _ = self.advance()
      let code_buf = StringBuilder()
      while self.pos < self.len && self.peek() != '`' && self.peek() != '\n' {
        code_buf.write_char(self.advance())
      }
      if self.peek() == '`' {
        let _ = self.advance()
      }
      self.at_line_start = false
      tokens.push(Token::InlineCode(code_buf.to_string()))
      continue
    }

    // Inline formatting: * (bold), _ (italic), $ (math)
    if c == '*' {
      let _ = self.advance()
      self.at_line_start = false
      tokens.push(Token::Star)
      continue
    }
    if c == '_' {
      let _ = self.advance()
      self.at_line_start = false
      tokens.push(Token::Underscore)
      continue
    }
    if c == '$' {
      let _ = self.advance()
      self.at_line_start = false
      tokens.push(Token::Dollar)
      continue
    }
    if c == '|' {
      let _ = self.advance()
      self.at_line_start = false
      tokens.push(Token::Bar)
      continue
    }
    if c == '[' {
      let _ = self.advance()
      self.at_line_start = false
      tokens.push(Token::LBracket)
      continue
    }
    if c == ']' {
      let _ = self.advance()
      self.at_line_start = false
      tokens.push(Token::RBracket)
      continue
    }
    if c == '(' {
      let _ = self.advance()
      self.at_line_start = false
      tokens.push(Token::LParen)
      continue
    }
    if c == ')' {
      let _ = self.advance()
      self.at_line_start = false
      tokens.push(Token::RParen)
      continue
    }
    if c == '/' {
      let _ = self.advance()
      self.at_line_start = false
      tokens.push(Token::Slash)
      continue
    }

    if c == '#' {
      let _ = self.advance()
      let id_buf = StringBuilder()
      while self.pos < self.len {
        let peek_c = self.peek()
        let is_ident = (peek_c >= 'a' && peek_c <= 'z') ||
          (peek_c >= 'A' && peek_c <= 'Z') ||
          peek_c == '_' ||
          (peek_c >= '0' && peek_c <= '9')
        if is_ident {
          id_buf.write_char(self.advance())
        } else {
          break
        }
      }
      let ident_name = id_buf.to_string()
      self.at_line_start = false
      tokens.push(Token::HashIdent(ident_name))
      continue
    }
    if c == ',' {
      let _ = self.advance()
      self.at_line_start = false
      tokens.push(Token::Comma)
      continue
    }
    if c == ':' {
      let _ = self.advance()
      self.at_line_start = false
      tokens.push(Token::Colon)
      continue
    }
    if c == ';' {
      let _ = self.advance()
      self.at_line_start = false
      tokens.push(Token::Semicolon)
      continue
    }
    if c == '=' {
      let _ = self.advance()
      self.at_line_start = false
      tokens.push(Token::Equal)
      continue
    }

    // Escaped character: \c
    if c == '\\' && self.pos + 1 < self.len {
      let _ = self.advance()
      let escaped = self.advance()
      let buf = StringBuilder()
      buf.write_char(escaped)
      self.at_line_start = false
      tokens.push(Token::Text(buf.to_string()))
      continue
    }

    // General text word or whitespace segment
    let text_buf = StringBuilder()
    while self.pos < self.len {
      let next_c = self.peek()
      if next_c == '\n' ||
        next_c == '\r' ||
        next_c == '*' ||
        next_c == '_' ||
        next_c == '`' ||
        next_c == '$' ||
        next_c == '|' ||
        next_c == '[' ||
        next_c == ']' ||
        next_c == '(' ||
        next_c == ')' ||
        next_c == '/' ||
        next_c == '\\' ||
        next_c == '#' ||
        next_c == ',' ||
        next_c == ':' ||
        next_c == ';' ||
        next_c == '=' {
        break
      }
      text_buf.write_char(self.advance())
    }
    let s = text_buf.to_string()
    if s.length() > 0 {
      self.at_line_start = false
      tokens.push(Token::Text(s))
    }
  }
  tokens.push(Token::Eof)
  tokens
}
