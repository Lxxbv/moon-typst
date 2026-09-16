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
    if c == '+' ||
      c == '-' ||
      c == '*' ||
      c == '=' ||
      c == '<' ||
      c == '>' ||
      c == '^' ||
      c == ',' ||
      c == ';' {
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

///|
/// Parse inner content of mat(...) into row count, col count, and elements
pub fn parse_matrix_inner(inner : String) -> (Int, Int, Array[@core.MathExpr]) {
  let rows_str : Array[String] = []
  let buf = StringBuilder()
  let len = inner.length()
  for i = 0; i < len; i = i + 1 {
    let c = inner[i].to_int().unsafe_to_char()
    if c == ';' {
      rows_str.push(buf.to_string())
      buf.reset()
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    rows_str.push(buf.to_string())
  }
  let elems : Array[@core.MathExpr] = []
  let mut max_cols = 0
  for row_s in rows_str {
    let col_buf = StringBuilder()
    let mut cols_in_row = 0
    let r_len = row_s.length()
    for j = 0; j < r_len; j = j + 1 {
      let rc = row_s[j].to_int().unsafe_to_char()
      if rc == ',' {
        let cell_text = col_buf.to_string().trim().to_owned()
        if cell_text.length() > 0 {
          elems.push(@core.MathExpr::Sym(cell_text))
        } else {
          elems.push(@core.MathExpr::Sym("0"))
        }
        cols_in_row = cols_in_row + 1
        col_buf.reset()
      } else {
        col_buf.write_char(rc)
      }
    }
    let last_cell = col_buf.to_string().trim().to_owned()
    if last_cell.length() > 0 {
      elems.push(@core.MathExpr::Sym(last_cell))
    } else {
      elems.push(@core.MathExpr::Sym("0"))
    }
    cols_in_row = cols_in_row + 1
    if cols_in_row > max_cols {
      max_cols = cols_in_row
    }
  }
  let row_count = if rows_str.length() > 0 { rows_str.length() } else { 1 }
  let col_count = if max_cols > 0 { max_cols } else { 1 }
  (row_count, col_count, elems)
}

///|
/// Parse inner content of vec(...) into column vector elements
pub fn parse_vec_inner(inner : String) -> Array[@core.MathExpr] {
  let elems : Array[@core.MathExpr] = []
  let buf = StringBuilder()
  let len = inner.length()
  for i = 0; i < len; i = i + 1 {
    let c = inner[i].to_int().unsafe_to_char()
    if c == ',' {
      let item = buf.to_string().trim().to_owned()
      if item.length() > 0 {
        elems.push(@core.MathExpr::Sym(item))
      }
      buf.reset()
    } else {
      buf.write_char(c)
    }
  }
  let last_item = buf.to_string().trim().to_owned()
  if last_item.length() > 0 {
    elems.push(@core.MathExpr::Sym(last_item))
  }
  elems
}
