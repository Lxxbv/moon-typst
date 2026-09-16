///|
/// Typst Document AST and models
/// Core data structures for representing parsed Typst markup.

///|
/// Mathematics expressions in Typst ($ ... $)
pub(all) enum MathExpr {
  Sym(String)
  Op(String)
  Frac(MathExpr, MathExpr)
  SubSup(MathExpr, MathExpr?, MathExpr?)
  Sqrt(MathExpr)
  Group(Array[MathExpr])
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
  HorizontalRule
} derive(Debug, Eq)

///|
/// Top-level document container
pub(all) struct Doc {
  blocks : Array[Block]
} derive(Debug, Eq)

///|
/// Constructor for empty document
pub fn Doc::new() -> Doc {
  { blocks: [] }
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
  }
}

///|
/// Calculate content width inside page margins
pub fn StyleContext::content_width(self : StyleContext) -> Double {
  self.page_width - self.margin_x * 2.0
}
