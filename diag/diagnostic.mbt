///|
/// Diagnostic severity levels
pub(all) enum Severity {
  Error
  Warning
  Hint
  Info
} derive(Eq, Debug)

///|
pub fn Severity::to_string(self : Severity) -> String {
  match self {
    Severity::Error => "error"
    Severity::Warning => "warning"
    Severity::Hint => "hint"
    Severity::Info => "info"
  }
}

///|
/// A compiler diagnostic reporting an error, warning, or hint with source location
pub(all) struct Diagnostic {
  severity : Severity
  message : String
  span : Span
  hint : String?
  code : String?
} derive(Eq, Debug)

///|
pub fn Diagnostic::error(msg : String, span : Span) -> Diagnostic {
  { severity: Severity::Error, message: msg, span, hint: None, code: None }
}

///|
pub fn Diagnostic::warning(msg : String, span : Span) -> Diagnostic {
  { severity: Severity::Warning, message: msg, span, hint: None, code: None }
}

///|
pub fn Diagnostic::hint(msg : String, span : Span) -> Diagnostic {
  { severity: Severity::Hint, message: msg, span, hint: None, code: None }
}

///|
pub fn Diagnostic::with_code(self : Diagnostic, code : String) -> Diagnostic {
  {
    severity: self.severity,
    message: self.message,
    span: self.span,
    hint: self.hint,
    code: Some(code),
  }
}

///|
pub fn Diagnostic::with_hint(self : Diagnostic, hint : String) -> Diagnostic {
  {
    severity: self.severity,
    message: self.message,
    span: self.span,
    hint: Some(hint),
    code: self.code,
  }
}

///|
/// Diagnostic reporter collecting errors and warnings, and rendering formatted output
pub(all) struct DiagnosticReporter {
  filename : String
  source : String
  lines : Array[String]
  diagnostics : Array[Diagnostic]
} derive(Eq, Debug)

///|
pub fn DiagnosticReporter::new(
  filename : String,
  source : String
) -> DiagnosticReporter {
  let lines : Array[String] = []
  let mut start = 0
  let len = source.length()
  for i = 0; i < len; i = i + 1 {
    let c = source[i].to_int().unsafe_to_char()
    if c == '\n' {
      let mut end = i
      if end > start && source[end - 1].to_int().unsafe_to_char() == '\r' {
        end = end - 1
      }
      lines.push(source[start:end].to_owned())
      start = i + 1
    }
  }
  if start < len {
    let mut end = len
    if end > start && source[end - 1].to_int().unsafe_to_char() == '\r' {
      end = end - 1
    }
    lines.push(source[start:end].to_owned())
  }
  { filename, source, lines, diagnostics: [] }
}

///|
pub fn DiagnosticReporter::add(
  self : DiagnosticReporter,
  d : Diagnostic
) -> Unit {
  self.diagnostics.push(d)
}

///|
pub fn DiagnosticReporter::has_errors(self : DiagnosticReporter) -> Bool {
  for d in self.diagnostics {
    if d.severity == Severity::Error {
      return true
    }
  }
  false
}

///|
pub fn DiagnosticReporter::count_errors(self : DiagnosticReporter) -> Int {
  let mut count = 0
  for d in self.diagnostics {
    if d.severity == Severity::Error {
      count = count + 1
    }
  }
  count
}

///|
pub fn DiagnosticReporter::count_warnings(self : DiagnosticReporter) -> Int {
  let mut count = 0
  for d in self.diagnostics {
    if d.severity == Severity::Warning {
      count = count + 1
    }
  }
  count
}

///|
fn repeat_char(c : Char, count : Int) -> String {
  let sb = StringBuilder()
  for i = 0; i < count; i = i + 1 {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
/// Formats a diagnostic with source code snippet, line numbers, and caret indicator
pub fn DiagnosticReporter::format_diagnostic(
  self : DiagnosticReporter,
  d : Diagnostic,
  use_color : Bool
) -> String {
  let sb = StringBuilder()

  // ANSI color escape codes
  let (color_prefix, color_suffix) = if use_color {
    match d.severity {
      Severity::Error => ("\u001b[1;31m", "\u001b[0m")
      Severity::Warning => ("\u001b[1;33m", "\u001b[0m")
      Severity::Hint => ("\u001b[1;36m", "\u001b[0m")
      Severity::Info => ("\u001b[1;34m", "\u001b[0m")
    }
  } else {
    ("", "")
  }

  // Header: error: message or error[E001]: message
  sb.write_string(color_prefix)
  sb.write_string(d.severity.to_string())
  match d.code {
    Some(code) => {
      sb.write_string("[")
      sb.write_string(code)
      sb.write_string("]")
    }
    None => ()
  }
  sb.write_string(": ")
  sb.write_string(d.message)
  sb.write_string(color_suffix)
  sb.write_string("\n")

  // Location pointer:   --> file.typ:line:col
  sb.write_string("  --> ")
  sb.write_string(self.filename)
  sb.write_string(":")
  sb.write_string(d.span.start.line.to_string())
  sb.write_string(":")
  sb.write_string(d.span.start.col.to_string())
  sb.write_string("\n")

  // Source line snippet
  let line_idx = d.span.start.line - 1
  if line_idx >= 0 && line_idx < self.lines.length() {
    let line_str = self.lines[line_idx]
    let line_no_str = d.span.start.line.to_string()
    let padding_len = line_no_str.length()
    let padding = repeat_char(' ', padding_len)

    sb.write_string("   ")
    sb.write_string(padding)
    sb.write_string(" |\n")

    sb.write_string("   ")
    sb.write_string(line_no_str)
    sb.write_string(" | ")
    sb.write_string(line_str)
    sb.write_string("\n")

    sb.write_string("   ")
    sb.write_string(padding)
    sb.write_string(" | ")

    // Caret line: spaces up to col, then carets
    let col = if d.span.start.col > 0 { d.span.start.col - 1 } else { 0 }
    let spaces = repeat_char(' ', col)
    sb.write_string(spaces)

    let mut caret_len = if d.span.end.line == d.span.start.line {
      d.span.end.col - d.span.start.col
    } else {
      1
    }
    if caret_len <= 0 {
      caret_len = 1
    }
    let carets = repeat_char('^', caret_len)
    sb.write_string(color_prefix)
    sb.write_string(carets)
    sb.write_string(color_suffix)
    sb.write_string("\n")
  }

  // Hint note if present
  match d.hint {
    Some(hint_text) => {
      sb.write_string("   = hint: ")
      sb.write_string(hint_text)
      sb.write_string("\n")
    }
    None => ()
  }

  sb.to_string()
}

///|
/// Formats all collected diagnostics
pub fn DiagnosticReporter::render_all(
  self : DiagnosticReporter,
  use_color : Bool
) -> String {
  let sb = StringBuilder()
  for d in self.diagnostics {
    sb.write_string(self.format_diagnostic(d, use_color))
    sb.write_string("\n")
  }
  let errors = self.count_errors()
  let warnings = self.count_warnings()
  if errors > 0 || warnings > 0 {
    sb.write_string("Finished with ")
    sb.write_string(errors.to_string())
    sb.write_string(" error(s) and ")
    sb.write_string(warnings.to_string())
    sb.write_string(" warning(s).\n")
  }
  sb.to_string()
}
