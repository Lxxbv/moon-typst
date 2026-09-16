///|
/// Source position representing a line and column in a text file (1-indexed)
pub(all) struct Pos {
  line : Int
  col : Int
} derive(Eq, Debug)

///|
pub fn Pos::new(line : Int, col : Int) -> Pos {
  { line, col, }
}

///|
pub fn Pos::default() -> Pos {
  { line: 1, col: 1, }
}

///|
pub fn Pos::compare(self : Pos, other : Pos) -> Int {
  if self.line != other.line {
    self.line - other.line
  } else {
    self.col - other.col
  }
}

///|
/// Source span representing a range between two positions [start, end)
pub(all) struct Span {
  start : Pos
  end : Pos
} derive(Eq, Debug)

///|
pub fn Span::new(start : Pos, end : Pos) -> Span {
  { start, end, }
}

///|
pub fn Span::point(line : Int, col : Int) -> Span {
  let p = Pos::new(line, col)
  { start: p, end: p, }
}

///|
pub fn Span::empty() -> Span {
  let p = Pos::default()
  { start: p, end: p, }
}

///|
pub fn Span::merge(self : Span, other : Span) -> Span {
  let start = if self.start.compare(other.start) <= 0 {
    self.start
  } else {
    other.start
  }
  let end = if self.end.compare(other.end) >= 0 { self.end } else { other.end }
  { start, end, }
}

///|
pub fn Span::to_string(self : Span) -> String {
  let sb = StringBuilder()
  sb.write_string(self.start.line.to_string())
  sb.write_string(":")
  sb.write_string(self.start.col.to_string())
  sb.write_string("-")
  sb.write_string(self.end.line.to_string())
  sb.write_string(":")
  sb.write_string(self.end.col.to_string())
  sb.to_string()
}
