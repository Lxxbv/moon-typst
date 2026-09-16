///|
/// Typst Document AST and models
/// Core data structures for representing parsed Typst markup.

///|
/// Text alignment options
pub(all) enum TextAlign {
  Left
  Center
  Right
  Justify
} derive(Debug, Eq)

///|
/// Shapes supported in Typst drawing commands
pub(all) enum ShapeKind {
  Rect(Length, Length, Double) // width, height, corner_radius
  Circle(Length) // radius
  Line(Length, Length, Length, Length) // x1, y1, x2, y2
  Polygon(Array[(Length, Length)]) // vertices
} derive(Debug, Eq)

///|
/// Visual styling attributes for vector shapes
pub(all) struct ShapeStyle {
  fill : Color?
  stroke : Color?
  stroke_width : Double
} derive(Debug, Eq)

///|
pub fn ShapeStyle::default() -> ShapeStyle {
  {
    fill: Some(Color::Luma(240)),
    stroke: Some(Color::Luma(50)),
    stroke_width: 1.0,
  }
}

///|
/// Mathematics expressions in Typst ($ ... $)
pub(all) enum MathExpr {
  Sym(String)
  Op(String)
  Frac(MathExpr, MathExpr)
  SubSup(MathExpr, MathExpr?, MathExpr?)
  Sqrt(MathExpr)
  Group(Array[MathExpr])
  Matrix(Int, Int, Array[MathExpr]) // rows, cols, elements
  Vec(Array[MathExpr]) // column vector elements
  Accent(MathExpr, String) // accent type ("hat", "tilde", "bar", "dot", "vec")
  Limits(MathExpr, MathExpr?, MathExpr?) // operator, lower, upper
} derive(Debug, Eq)

///|
/// Inline document elements
pub(all) enum Inline {
  Text(String)
  Bold(Array[Inline])
  Italic(Array[Inline])
  Code(String)
  InlineMath(MathExpr)
  Link(String, String) // url, display_text
  FootnoteRef(Int) // [^1]
  StyledSpan(Array[Inline], Color?, Double?) // inlines, text_color, font_size
  LineBreak
} derive(Debug, Eq)

///|
/// Block-level document elements
pub(all) enum Block {
  Heading(Int, Array[Inline]) // level (1-6), content
  Paragraph(Array[Inline])
  List(Bool, Array[Array[Inline]]) // is_ordered, items
  CodeBlock(String, String) // language, code_content
  MathBlock(MathExpr)
  Table(Int, Array[Array[Inline]]) // column_count, cells
  Shape(ShapeKind, ShapeStyle)
  Grid(Array[Length], Array[Block]) // column tracks, cell items
  FootnoteBlock(Int, Array[Inline]) // footnote definition
  Figure(Block, Array[Inline]?) // body block, caption
  AlignBlock(TextAlign, Block)
  HorizontalRule
  PageBreak
} derive(Debug, Eq)

///|
/// Top-level document container
pub(all) struct Doc {
  blocks : Array[Block]
} derive(Debug, Eq)

///|
/// Constructor for empty document
pub fn Doc::new() -> Doc {
  { blocks: [], }
}

///|
/// Add a block element to document
pub fn Doc::add_block(self : Doc, block : Block) -> Unit {
  self.blocks.push(block)
}

///|
/// Styling and page layout configuration
pub(all) struct StyleContext {
  page_width : Double
  page_height : Double
  margin_x : Double
  margin_y : Double
  font_size : Double
  line_height : Double
  text_color : String
  bg_color : String
  code_bg_color : String
  font_family : String
  columns : Int
  column_gap : Double
  text_align : TextAlign
  header : Array[Inline]?
  footer : Array[Inline]?
} derive(Debug, Eq)

///|
/// Standard default style (A4-proportional web layout)
pub fn StyleContext::default() -> StyleContext {
  {
    page_width: 800.0,
    page_height: 1100.0,
    margin_x: 48.0,
    margin_y: 48.0,
    font_size: 16.0,
    line_height: 1.5,
    text_color: "#1a1a1a",
    bg_color: "#ffffff",
    code_bg_color: "#f4f4f6",
    font_family: "system-ui, -apple-system, sans-serif",
    columns: 1,
    column_gap: 24.0,
    text_align: TextAlign::Left,
    header: None,
    footer: None,
  }
}

///|
/// Calculate content width inside page margins
pub fn StyleContext::content_width(self : StyleContext) -> Double {
  self.page_width - self.margin_x * 2.0
}

///|
/// Calculate single column width when in multi-column layout
pub fn StyleContext::column_width(self : StyleContext) -> Double {
  let total_w = self.content_width()
  if self.columns <= 1 {
    total_w
  } else {
    let gaps = (self.columns - 1).to_double() * self.column_gap
    (total_w - gaps) / self.columns.to_double()
  }
}
