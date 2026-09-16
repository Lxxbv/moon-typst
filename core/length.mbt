///|
/// Physical and relative typographical length dimensions in Typst
pub(all) enum Length {
  Pt(Double)
  Mm(Double)
  Cm(Double)
  Em(Double)
  Fr(Double)
  Percent(Double)
} derive(Debug, Eq)

///|
/// Convert typographical unit to typographic points (1 pt = 1/72 inch)
pub fn Length::to_pt(
  self : Length,
  em_size : Double,
  container_width : Double
) -> Double {
  match self {
    Length::Pt(v) => v
    Length::Mm(v) => v * 72.0 / 25.4
    Length::Cm(v) => v * 72.0 / 2.54
    Length::Em(v) => v * em_size
    Length::Fr(v) => v * container_width
    Length::Percent(v) => v / 100.0 * container_width
  }
}

///|
pub fn Length::zero() -> Length {
  Length::Pt(0.0)
}

///|
pub fn Length::pt(val : Double) -> Length {
  Length::Pt(val)
}

///|
pub fn Length::em(val : Double) -> Length {
  Length::Em(val)
}

///|
pub fn Length::percent(val : Double) -> Length {
  Length::Percent(val)
}

///|
pub fn Length::to_string(self : Length) -> String {
  match self {
    Length::Pt(v) => v.to_string() + "pt"
    Length::Mm(v) => v.to_string() + "mm"
    Length::Cm(v) => v.to_string() + "cm"
    Length::Em(v) => v.to_string() + "em"
    Length::Fr(v) => v.to_string() + "fr"
    Length::Percent(v) => v.to_string() + "%"
  }
}
