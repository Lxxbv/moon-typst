///|
/// Geometric Box Model definitions for Typst document layout
pub(all) struct Rect {
  x : Double
  y : Double
  w : Double
  h : Double
} derive(Debug, Eq)

///|
pub fn Rect::new(x : Double, y : Double, w : Double, h : Double) -> Rect {
  { x, y, w, h }
}

///|
pub(all) enum BoxKind {
  Text(String, Double, String, String) // text, font_size, color, font_weight
  RectFill(Double, Double, String, Double) // width, height, fill_color, border_radius
  RectStroke(Double, Double, String, Double) // width, height, stroke_color, stroke_width
  Line(Double, Double, Double, Double, String, Double) // x1, y1, x2, y2, stroke_color, stroke_width
  Container(Array[LayoutBox])
} derive(Debug, Eq)

///|
pub(all) struct LayoutBox {
  rect : Rect
  kind : BoxKind
} derive(Debug, Eq)

///|
pub fn LayoutBox::new(rect : Rect, kind : BoxKind) -> LayoutBox {
  { rect, kind }
}

///|
pub(all) struct PageLayout {
  width : Double
  height : Double
  boxes : Array[LayoutBox]
} derive(Debug, Eq)
