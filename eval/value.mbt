///|
/// Runtime values for Typst expression evaluation and function calls
pub(all) enum Val {
  Int(Int)
  Float(Double)
  Str(String)
  Bool(Bool)
  Length(@core.Length)
  Color(@core.Color)
  Align(@core.TextAlign)
  Array(Array[Val])
  Dict(Array[(String, Val)])
  BlockContent(@core.Block)
  InlineContent(@core.Inline)
  None
} derive(Debug, Eq)

///|
pub fn Val::to_string(self : Val) -> String {
  match self {
    Val::Int(i) => i.to_string()
    Val::Float(f) => f.to_string()
    Val::Str(s) => s
    Val::Bool(b) => b.to_string()
    Val::Length(l) => l.to_string()
    Val::Color(c) => c.to_hex()
    Val::Align(a) =>
      match a {
        @core.TextAlign::Left => "left"
        @core.TextAlign::Center => "center"
        @core.TextAlign::Right => "right"
        @core.TextAlign::Justify => "justify"
      }
    Val::Array(arr) => {
      let sb = StringBuilder()
      sb.write_string("(")
      for i, item in arr {
        if i > 0 {
          sb.write_string(", ")
        }
        sb.write_string(item.to_string())
      }
      sb.write_string(")")
      sb.to_string()
    }
    Val::Dict(pairs) => {
      let sb = StringBuilder()
      sb.write_string("(")
      for i, pair in pairs {
        if i > 0 {
          sb.write_string(", ")
        }
        sb.write_string(pair.0)
        sb.write_string(": ")
        sb.write_string(pair.1.to_string())
      }
      sb.write_string(")")
      sb.to_string()
    }
    Val::BlockContent(_) => "[block content]"
    Val::InlineContent(_) => "[inline content]"
    Val::None => "none"
  }
}

///|
pub fn Val::as_int(self : Val) -> Int? {
  match self {
    Val::Int(i) => Some(i)
    _ => Option::None
  }
}

///|
pub fn Val::as_double(self : Val) -> Double? {
  match self {
    Val::Float(f) => Some(f)
    Val::Int(i) => Some(i.to_double())
    _ => Option::None
  }
}

///|
pub fn Val::as_str(self : Val) -> String? {
  match self {
    Val::Str(s) => Some(s)
    _ => Option::None
  }
}

///|
pub fn Val::as_bool(self : Val) -> Bool? {
  match self {
    Val::Bool(b) => Some(b)
    _ => Option::None
  }
}

///|
pub fn Val::as_length(self : Val) -> @core.Length? {
  match self {
    Val::Length(l) => Some(l)
    Val::Float(f) => Some(@core.Length::Pt(f))
    Val::Int(i) => Some(@core.Length::Pt(i.to_double()))
    _ => Option::None
  }
}

///|
pub fn Val::as_color(self : Val) -> @core.Color? {
  match self {
    Val::Color(c) => Some(c)
    Val::Str(s) => Some(@core.Color::Named(s))
    _ => Option::None
  }
}

///|
pub fn Val::as_align(self : Val) -> @core.TextAlign? {
  match self {
    Val::Align(a) => Some(a)
    Val::Str(s) =>
      match s {
        "center" => Some(@core.TextAlign::Center)
        "right" => Some(@core.TextAlign::Right)
        "justify" => Some(@core.TextAlign::Justify)
        _ => Some(@core.TextAlign::Left)
      }
    _ => Option::None
  }
}

///|
pub fn Val::get_prop(self : Val, key : String) -> Val? {
  match self {
    Val::Dict(pairs) => {
      for pair in pairs {
        if pair.0 == key {
          return Some(pair.1)
        }
      }
      Option::None
    }
    _ => Option::None
  }
}
