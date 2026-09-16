///|
/// Typst Token definitions for lexical analysis
pub(all) enum Token {
  Eof
  Newline
  HeadingPrefix(Int) // 1 to 6
  Star // * (bold toggle)
  Underscore // _ (italic toggle)
  InlineCode(String) // `code`
  RawBlock(String, String) // language, code content
  Dollar // $ (math toggle)
  DashItem // - (unordered list item)
  PlusItem // + (ordered list item)
  Text(String) // raw word or punctuation
  HorizontalRule // ---
  Bar // | (table delimiter)
  LBracket // [
  RBracket // ]
  LParen // (
  RParen // )
  Slash // /
  HashIdent(String) // #set, #rect, #grid, etc.
  Comma // ,
  Colon // :
  Semicolon // ;
  Equal // =
} derive(Debug, Eq)
