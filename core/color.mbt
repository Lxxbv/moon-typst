///|
/// Color representations supported in Typst styling
pub(all) enum Color {
  Rgb(Int, Int, Int, Double) // r, g, b (0-255), alpha (0.0-1.0)
  Luma(Int) // 0-255 grayscale
  Named(String) // "red", "blue", "black", etc.
} derive(Debug, Eq)

///|
fn hex_digit(d : Int) -> Char {
  if d < 10 {
    (d + 48).unsafe_to_char()
  } else {
    (d - 10 + 97).unsafe_to_char()
  }
}

///|
fn to_hex2(val : Int) -> String {
  let clamped = if val < 0 { 0 } else if val > 255 { 255 } else { val }
  let high = clamped / 16
  let low = clamped % 16
  let sb = StringBuilder()
  sb.write_char(hex_digit(high))
  sb.write_char(hex_digit(low))
  sb.to_string()
}

///|
/// Convert Color into CSS/SVG hexadecimal string format "#rrggbb"
pub fn Color::to_hex(self : Color) -> String {
  match self {
    Color::Rgb(r, g, b, _a) => "#" + to_hex2(r) + to_hex2(g) + to_hex2(b)
    Color::Luma(v) => "#" + to_hex2(v) + to_hex2(v) + to_hex2(v)
    Color::Named(name) =>
      match name {
        "black" => "#000000"
        "white" => "#ffffff"
        "red" => "#cf222e"
        "green" => "#1a7f37"
        "blue" => "#0969da"
        "yellow" => "#9a6700"
        "gray" | "grey" => "#6e7781"
        _ => name
      }
  }
}

///|
/// Convert Color into normalized (R, G, B, A) tuple in [0.0, 1.0] for PDF and vector rendering
pub fn Color::to_normalized(self : Color) -> (Double, Double, Double, Double) {
  match self {
    Color::Rgb(r, g, b, a) =>
      (
        r.to_double() / 255.0,
        g.to_double() / 255.0,
        b.to_double() / 255.0,
        a,
      )
    Color::Luma(v) => {
      let d = v.to_double() / 255.0
      (d, d, d, 1.0)
    }
    Color::Named(name) =>
      match name {
        "black" => (0.0, 0.0, 0.0, 1.0)
        "white" => (1.0, 1.0, 1.0, 1.0)
        "red" => (0.8, 0.1, 0.1, 1.0)
        "green" => (0.1, 0.5, 0.2, 1.0)
        "blue" => (0.04, 0.41, 0.85, 1.0)
        "gray" | "grey" => (0.5, 0.5, 0.5, 1.0)
        _ => (0.0, 0.0, 0.0, 1.0)
      }
  }
}
