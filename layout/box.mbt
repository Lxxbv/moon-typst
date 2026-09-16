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
  Circle(Double, String, String, Double) // radius, fill_color, stroke_color, stroke_width
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

///|
pub fn PageLayout::new(width : Double, height : Double) -> PageLayout {
  { width, height, boxes: [] }
}

///|
pub fn PageLayout::add_box(self : PageLayout, b : LayoutBox) -> Unit {
  self.boxes.push(b)
}

///|
/// Document containing one or more laid out pages
pub(all) struct DocumentLayout {
  pages : Array[PageLayout]
} derive(Debug, Eq)

///|
pub fn DocumentLayout::new() -> DocumentLayout {
  { pages: [] }
}

///|
pub fn DocumentLayout::single_page(page : PageLayout) -> DocumentLayout {
  { pages: [page] }
}
