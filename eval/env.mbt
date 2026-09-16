///|
/// Lexical scope holding variable bindings
pub(all) struct Scope {
  bindings : Array[(String, Val)]
} derive(Debug, Eq)

///|
pub fn Scope::new() -> Scope {
  { bindings: [], }
}

///|
pub fn Scope::set(self : Scope, name : String, val : Val) -> Unit {
  for i = 0; i < self.bindings.length(); i = i + 1 {
    if self.bindings[i].0 == name {
      self.bindings[i] = (name, val)
      return
    }
  }
  self.bindings.push((name, val))
}

///|
pub fn Scope::get(self : Scope, name : String) -> Val? {
  for pair in self.bindings {
    if pair.0 == name {
      return Some(pair.1)
    }
  }
  Option::None
}

///|
/// Runtime evaluator managing cascading styles, variable scopes, and diagnostics
pub(all) struct Evaluator {
  scopes : Array[Scope]
  mut style : @core.StyleContext
  reporter : @diag.DiagnosticReporter
} derive(Debug)

///|
pub fn Evaluator::new(
  style : @core.StyleContext,
  reporter : @diag.DiagnosticReporter,
) -> Evaluator {
  let root = Scope::new()
  // Preset default constants
  root.set("true", Val::Bool(true))
  root.set("false", Val::Bool(false))
  root.set("none", Val::None)
  root.set("pt", Val::Str("pt"))
  root.set("mm", Val::Str("mm"))
  root.set("cm", Val::Str("cm"))
  root.set("em", Val::Str("em"))
  root.set("red", Val::Color(@core.Color::Named("red")))
  root.set("blue", Val::Color(@core.Color::Named("blue")))
  root.set("green", Val::Color(@core.Color::Named("green")))
  root.set("black", Val::Color(@core.Color::Named("black")))
  root.set("white", Val::Color(@core.Color::Named("white")))
  root.set("gray", Val::Color(@core.Color::Named("gray")))
  { scopes: [root], style, reporter, }
}

///|
pub fn Evaluator::push_scope(self : Evaluator) -> Unit {
  self.scopes.push(Scope::new())
}

///|
pub fn Evaluator::pop_scope(self : Evaluator) -> Unit {
  if self.scopes.length() > 1 {
    let _ = self.scopes.pop()
  }
}

///|
pub fn Evaluator::set_var(self : Evaluator, name : String, val : Val) -> Unit {
  if self.scopes.length() > 0 {
    let top_idx = self.scopes.length() - 1
    self.scopes[top_idx].set(name, val)
  }
}

///|
pub fn Evaluator::lookup_var(self : Evaluator, name : String) -> Val? {
  let mut i = self.scopes.length() - 1
  while i >= 0 {
    match self.scopes[i].get(name) {
      Some(v) => return Some(v)
      None => ()
    }
    i = i - 1
  }
  Option::None
}

///|
/// Apply a `#set` rule to cascading style context (e.g. `#set text(...)` or `#set page(...)`)
pub fn Evaluator::apply_set_rule(
  self : Evaluator,
  target : String,
  args : Array[(String, Val)],
) -> Unit {
  match target {
    "text" =>
      for pair in args {
        match pair.0 {
          "size" =>
            match pair.1.as_length() {
              Some(l) =>
                self.style = {
                  ..self.style,
                  font_size: l.to_pt(
                    self.style.font_size,
                    self.style.content_width(),
                  ),
                }
              None => ()
            }
          "fill" =>
            match pair.1.as_color() {
              Some(c) => self.style = { ..self.style, text_color: c.to_hex(), }
              None => ()
            }
          "font" =>
            match pair.1.as_str() {
              Some(f) => self.style = { ..self.style, font_family: f, }
              None => ()
            }
          _ => ()
        }
      }
    "page" =>
      for pair in args {
        match pair.0 {
          "columns" =>
            match pair.1.as_int() {
              Some(c) => self.style = { ..self.style, columns: c, }
              None => ()
            }
          "gap" =>
            match pair.1.as_length() {
              Some(l) =>
                self.style = {
                  ..self.style,
                  column_gap: l.to_pt(
                    self.style.font_size,
                    self.style.content_width(),
                  ),
                }
              None => ()
            }
          "margin" =>
            match pair.1.as_length() {
              Some(l) => {
                let m = l.to_pt(self.style.font_size, self.style.page_width)
                self.style = { ..self.style, margin_x: m, margin_y: m, }
              }
              None => ()
            }
          "width" =>
            match pair.1.as_length() {
              Some(l) =>
                self.style = {
                  ..self.style,
                  page_width: l.to_pt(self.style.font_size, 800.0),
                }
              None => ()
            }
          "height" =>
            match pair.1.as_length() {
              Some(l) =>
                self.style = {
                  ..self.style,
                  page_height: l.to_pt(self.style.font_size, 1100.0),
                }
              None => ()
            }
          _ => ()
        }
      }
    "par" =>
      for pair in args {
        match pair.0 {
          "justify" =>
            match pair.1.as_bool() {
              Some(true) =>
                self.style = {
                  ..self.style,
                  text_align: @core.TextAlign::Justify,
                }
              Some(false) =>
                self.style = {
                  ..self.style,
                  text_align: @core.TextAlign::Left,
                }
              None => ()
            }
          "align" =>
            match pair.1.as_align() {
              Some(a) => self.style = { ..self.style, text_align: a, }
              None => ()
            }
          "leading" =>
            match pair.1.as_double() {
              Some(d) => self.style = { ..self.style, line_height: d, }
              None => ()
            }
          _ => ()
        }
      }
    _ => ()
  }
}
