///|
/// Built-in function evaluation and layout element factories
fn get_named_arg(named : Array[(String, Val)], key : String) -> Val? {
  for pair in named {
    if pair.0 == key {
      return Some(pair.1)
    }
  }
  Option::None
}

///|
/// Dispatches a built-in Typst function call to produce a runtime Val
pub fn eval_builtin(
  name : String,
  pos_args : Array[Val],
  named_args : Array[(String, Val)],
) -> Val {
  match name {
    "rect" => {
      let width = match get_named_arg(named_args, "width") {
        Some(v) =>
          match v.as_length() {
            Some(l) => l
            None => @core.Length::Pt(100.0)
          }
        None =>
          if pos_args.length() > 0 {
            match pos_args[0].as_length() {
              Some(l) => l
              None => @core.Length::Pt(100.0)
            }
          } else {
            @core.Length::Pt(100.0)
          }
      }
      let height = match get_named_arg(named_args, "height") {
        Some(v) =>
          match v.as_length() {
            Some(l) => l
            None => @core.Length::Pt(60.0)
          }
        None =>
          if pos_args.length() > 1 {
            match pos_args[1].as_length() {
              Some(l) => l
              None => @core.Length::Pt(60.0)
            }
          } else {
            @core.Length::Pt(60.0)
          }
      }
      let radius = match get_named_arg(named_args, "radius") {
        Some(v) =>
          match v.as_double() {
            Some(d) => d
            None => 0.0
          }
        None => 0.0
      }
      let fill_color = match get_named_arg(named_args, "fill") {
        Some(v) => v.as_color()
        None => Some(@core.Color::Luma(240))
      }
      let stroke_color = match get_named_arg(named_args, "stroke") {
        Some(v) => v.as_color()
        None => Some(@core.Color::Luma(50))
      }
      let style : @core.ShapeStyle = {
        fill: fill_color,
        stroke: stroke_color,
        stroke_width: 1.0,
      }
      let shape = @core.ShapeKind::Rect(width, height, radius)
      Val::BlockContent(@core.Block::Shape(shape, style))
    }
    "circle" => {
      let radius = match get_named_arg(named_args, "radius") {
        Some(v) =>
          match v.as_length() {
            Some(l) => l
            None => @core.Length::Pt(30.0)
          }
        None =>
          if pos_args.length() > 0 {
            match pos_args[0].as_length() {
              Some(l) => l
              None => @core.Length::Pt(30.0)
            }
          } else {
            @core.Length::Pt(30.0)
          }
      }
      let fill_color = match get_named_arg(named_args, "fill") {
        Some(v) => v.as_color()
        None => Some(@core.Color::Named("blue"))
      }
      let stroke_color = match get_named_arg(named_args, "stroke") {
        Some(v) => v.as_color()
        None => None
      }
      let style : @core.ShapeStyle = {
        fill: fill_color,
        stroke: stroke_color,
        stroke_width: 1.0,
      }
      let shape = @core.ShapeKind::Circle(radius)
      Val::BlockContent(@core.Block::Shape(shape, style))
    }
    "line" => {
      let x1 = match get_named_arg(named_args, "x1") {
        Some(v) =>
          match v.as_length() {
            Some(l) => l
            None => @core.Length::Pt(0.0)
          }
        None => @core.Length::Pt(0.0)
      }
      let y1 = match get_named_arg(named_args, "y1") {
        Some(v) =>
          match v.as_length() {
            Some(l) => l
            None => @core.Length::Pt(0.0)
          }
        None => @core.Length::Pt(0.0)
      }
      let x2 = match get_named_arg(named_args, "x2") {
        Some(v) =>
          match v.as_length() {
            Some(l) => l
            None => @core.Length::Pt(100.0)
          }
        None => @core.Length::Pt(100.0)
      }
      let y2 = match get_named_arg(named_args, "y2") {
        Some(v) =>
          match v.as_length() {
            Some(l) => l
            None => @core.Length::Pt(0.0)
          }
        None => @core.Length::Pt(0.0)
      }
      let stroke_color = match get_named_arg(named_args, "stroke") {
        Some(v) => v.as_color()
        None => Some(@core.Color::Named("black"))
      }
      let style : @core.ShapeStyle = {
        fill: None,
        stroke: stroke_color,
        stroke_width: 1.0,
      }
      let shape = @core.ShapeKind::Line(x1, y1, x2, y2)
      Val::BlockContent(@core.Block::Shape(shape, style))
    }
    "grid" => {
      let cols_arg = match get_named_arg(named_args, "columns") {
        Some(Val::Array(arr)) => {
          let cols : Array[@core.Length] = []
          for v in arr {
            match v.as_length() {
              Some(l) => cols.push(l)
              None => cols.push(@core.Length::Fr(1.0))
            }
          }
          cols
        }
        _ => [@core.Length::Fr(1.0), @core.Length::Fr(1.0)]
      }
      let items : Array[@core.Block] = []
      for arg in pos_args {
        match arg {
          Val::BlockContent(b) => items.push(b)
          Val::InlineContent(inl) => items.push(@core.Block::Paragraph([inl]))
          Val::Str(s) =>
            items.push(@core.Block::Paragraph([@core.Inline::Text(s)]))
          _ => ()
        }
      }
      Val::BlockContent(@core.Block::Grid(cols_arg, items))
    }
    "align" => {
      let align_val = if pos_args.length() > 0 {
        match pos_args[0].as_align() {
          Some(a) => a
          None => @core.TextAlign::Left
        }
      } else {
        @core.TextAlign::Left
      }
      let body = if pos_args.length() > 1 {
        match pos_args[1] {
          Val::BlockContent(b) => b
          Val::InlineContent(i) => @core.Block::Paragraph([i])
          Val::Str(s) => @core.Block::Paragraph([@core.Inline::Text(s)])
          _ => @core.Block::Paragraph([])
        }
      } else {
        @core.Block::Paragraph([])
      }
      Val::BlockContent(@core.Block::AlignBlock(align_val, body))
    }
    "rgb" => {
      let r = if pos_args.length() > 0 {
        match pos_args[0].as_int() {
          Some(v) => v
          None => 0
        }
      } else {
        0
      }
      let g = if pos_args.length() > 1 {
        match pos_args[1].as_int() {
          Some(v) => v
          None => 0
        }
      } else {
        0
      }
      let b = if pos_args.length() > 2 {
        match pos_args[2].as_int() {
          Some(v) => v
          None => 0
        }
      } else {
        0
      }
      let a = if pos_args.length() > 3 {
        match pos_args[3].as_double() {
          Some(v) => v
          None => 1.0
        }
      } else {
        1.0
      }
      Val::Color(@core.Color::Rgb(r, g, b, a))
    }
    "luma" => {
      let v = if pos_args.length() > 0 {
        match pos_args[0].as_int() {
          Some(val) => val
          None => 0
        }
      } else {
        0
      }
      Val::Color(@core.Color::Luma(v))
    }
    _ => Val::None
  }
}
