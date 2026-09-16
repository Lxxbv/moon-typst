///|
/// Helper to split math text into atoms (operators, symbols, numbers)
fn split_math_tokens(s : String) -> Array[String] {
  let result : Array[String] = []
  let buf = StringBuilder()
  let len = s.length()
  let mut i = 0
  while i < len {
    let c = s[i].to_int().unsafe_to_char()
    if c == ' ' || c == '\t' {
      if buf.to_string().length() > 0 {
        result.push(buf.to_string())
        buf.reset()
      }
      i = i + 1
      continue
    }
    if c == '+' || c == '-' || c == '*' || c == '=' || c == '<' || c == '>' ||
       c == '^' || c == ',' {
      if buf.to_string().length() > 0 {
        result.push(buf.to_string())
        buf.reset()
      }
      let op_buf = StringBuilder()
      op_buf.write_char(c)
      result.push(op_buf.to_string())
      i = i + 1
      continue
    }
    buf.write_char(c)
    i = i + 1
  }
  if buf.to_string().length() > 0 {
    result.push(buf.to_string())
  }
  result
}
