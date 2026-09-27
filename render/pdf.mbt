///|
/// Pure MoonBit PDF 1.4 vector document generator.
/// CJK glyphs use a standard non-embedded CID font and may be substituted by readers.

///|
/// Escape text for PDF literal string (...)
pub fn escape_pdf_string(s : String) -> String {
  let sb = StringBuilder()
  let len = s.length()
  for i = 0; i < len; i = i + 1 {
    let c = s[i].to_int().unsafe_to_char()
    match c {
      '(' => sb.write_string("\\(")
      ')' => sb.write_string("\\)")
      '\\' => sb.write_string("\\\\")
      '\r' => sb.write_string("\\r")
      '\n' => sb.write_string("\\n")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// PDF Object offset tracker and serializer
pub struct PdfWriter {
  buf : StringBuilder
  offsets : Array[Int]
  mut byte_count : Int
}

///|
pub fn PdfWriter::new() -> PdfWriter {
  { buf: StringBuilder(), offsets: [], byte_count: 0, }
}

///|
fn PdfWriter::write_bytes(self : PdfWriter, s : String) -> Unit {
  self.buf.write_string(s)
  self.byte_count = self.byte_count + @unicode.to_utf8_bytes(s).length()
}

///|
fn PdfWriter::start_obj(self : PdfWriter, obj_id : Int) -> Unit {
  while self.offsets.length() < obj_id {
    self.offsets.push(0)
  }
  self.offsets[obj_id - 1] = self.byte_count
  self.write_bytes(obj_id.to_string() + " 0 obj\n")
}

///|
fn PdfWriter::end_obj(self : PdfWriter) -> Unit {
  self.write_bytes("endobj\n")
}

///|
/// Encode UTF-16 code units as a PDF hex string for the UniGB-UCS2-H CMap.
fn encode_pdf_unicode_hex(s : String) -> String {
  let digits = "0123456789ABCDEF"
  let sb = StringBuilder()
  let mut i = 0
  while i < s.length() {
    let unit = s.code_unit_at(i).to_int()
    if unit >= 55296 && unit <= 56319 {
      // The PDF 1.4 UniGB-UCS2-H CMap accepts BMP characters only.
      // Replace a supplementary character (a surrogate pair) with '?' rather
      // than emitting an unmappable CID sequence.
      append_pdf_hex_unit(sb, digits, 63)
      if i + 1 < s.length() &&
        s.code_unit_at(i + 1) >= 56320 &&
        s.code_unit_at(i + 1) <= 57343 {
        i = i + 2
      } else {
        i = i + 1
      }
    } else if unit >= 56320 && unit <= 57343 {
      append_pdf_hex_unit(sb, digits, 63)
      i = i + 1
    } else {
      append_pdf_hex_unit(sb, digits, unit)
      i = i + 1
    }
  }
  "<" + sb.to_string() + ">"
}

///|
fn append_pdf_hex_unit(sb : StringBuilder, digits : String, unit : Int) -> Unit {
  sb.write_char(digits[(unit >> 12) & 15].to_int().unsafe_to_char())
  sb.write_char(digits[(unit >> 8) & 15].to_int().unsafe_to_char())
  sb.write_char(digits[(unit >> 4) & 15].to_int().unsafe_to_char())
  sb.write_char(digits[unit & 15].to_int().unsafe_to_char())
}

///|
fn unicode_to_unicode_cmap() -> String {
  (
    #|/CIDInit /ProcSet findresource begin
    #|12 dict begin
    #|begincmap
    #|/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
    #|/CMapName /Adobe-Identity-UCS def
    #|/CMapType 2 def
    #|1 begincodespacerange
    #|<0000> <FFFF>
    #|endcodespacerange
    #|2 beginbfrange
    #|<0000> <D7FF> <0000>
    #|<E000> <FFFF> <E000>
    #|endbfrange
    #|endcmap
    #|CMapName currentdict /CMap defineresource pop
    #|end
    #|end
  )
}

///|
fn format_offset(offset : Int) -> String {
  let s = offset.to_string()
  let pad_len = 10 - s.length()
  let sb = StringBuilder()
  for i = 0; i < pad_len; i = i + 1 {
    sb.write_char('0')
  }
  sb.write_string(s)
  sb.to_string()
}

///|
/// Render a single PageLayout into a standalone PDF 1.4 document string
pub fn render_pdf(page : @layout.PageLayout) -> String {
  let doc_layout = @layout.DocumentLayout::single_page(page)
  render_pdf_document(doc_layout)
}

///|
/// Render a multi-page DocumentLayout into standard PDF 1.4 binary data
pub fn render_pdf_document(doc : @layout.DocumentLayout) -> String {
  let writer = PdfWriter::new()
  let page_count = if doc.pages.length() > 0 { doc.pages.length() } else { 1 }

  // PDF Header
  writer.write_bytes("%PDF-1.4\n%\u00e2\u00e3\u00cf\u00d3\n")

  // Object 1: Catalog
  writer.start_obj(1)
  writer.write_bytes("<< /Type /Catalog /Pages 2 0 R >>\n")
  writer.end_obj()

  // Object 2: Pages Tree
  let first_page_obj = 3
  let font_catalog_obj = first_page_obj + page_count * 2
  let font_helvetica = font_catalog_obj + 1
  let font_helvetica_bold = font_catalog_obj + 2
  let font_times_italic = font_catalog_obj + 3
  let font_courier = font_catalog_obj + 4
  let font_cjk = font_catalog_obj + 5
  let font_cjk_descendant = font_catalog_obj + 6
  let font_cjk_descriptor = font_catalog_obj + 7
  let font_to_unicode = font_catalog_obj + 8

  writer.start_obj(2)
  let kids_sb = StringBuilder()
  kids_sb.write_string("[")
  for p = 0; p < page_count; p = p + 1 {
    let p_obj = first_page_obj + p * 2
    if p > 0 {
      kids_sb.write_string(" ")
    }
    kids_sb.write_string(p_obj.to_string() + " 0 R")
  }
  kids_sb.write_string("]")
  writer.write_bytes(
    "<< /Type /Pages /Kids " +
    kids_sb.to_string() +
    " /Count " +
    page_count.to_string() +
    " >>\n",
  )
  writer.end_obj()

  // For each page: Page Object (3 + 2*p) and Contents Stream (4 + 2*p)
  for p = 0; p < page_count; p = p + 1 {
    let page_obj_id = first_page_obj + p * 2
    let content_obj_id = page_obj_id + 1
    let cur_page = if p < doc.pages.length() {
      doc.pages[p]
    } else {
      @layout.PageLayout::new(800.0, 1100.0)
    }

    // Page Object
    writer.start_obj(page_obj_id)
    writer.write_bytes(
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 " +
      cur_page.width.to_string() +
      " " +
      cur_page.height.to_string() +
      "] /Contents " +
      content_obj_id.to_string() +
      " 0 R /Resources " +
      font_catalog_obj.to_string() +
      " 0 R >>\n",
    )
    writer.end_obj()

    // Page Content Stream
    let stream_buf = StringBuilder()
    encode_page_stream(stream_buf, cur_page)
    let stream_str = stream_buf.to_string()

    writer.start_obj(content_obj_id)
    writer.write_bytes(
      "<< /Length " +
      @unicode.to_utf8_bytes(stream_str).length().to_string() +
      " >>\nstream\n" +
      stream_str +
      "\nendstream\n",
    )
    writer.end_obj()
  }

  // Resources Object: Fonts & ProcSet
  writer.start_obj(font_catalog_obj)
  writer.write_bytes(
    "<< /ProcSet [/PDF /Text /ImageB /ImageC /ImageI] /Font << /F1 " +
    font_helvetica.to_string() +
    " 0 R /F2 " +
    font_helvetica_bold.to_string() +
    " 0 R /F3 " +
    font_times_italic.to_string() +
    " 0 R /F4 " +
    font_courier.to_string() +
    " 0 R /F5 " +
    font_cjk.to_string() +
    " 0 R >> >>\n",
  )
  writer.end_obj()

  // Font 1: Helvetica (Regular)
  writer.start_obj(font_helvetica)
  writer.write_bytes(
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\n",
  )
  writer.end_obj()

  // Font 2: Helvetica-Bold
  writer.start_obj(font_helvetica_bold)
  writer.write_bytes(
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>\n",
  )
  writer.end_obj()

  // Font 3: Times-Italic
  writer.start_obj(font_times_italic)
  writer.write_bytes(
    "<< /Type /Font /Subtype /Type1 /BaseFont /Times-Italic /Encoding /WinAnsiEncoding >>\n",
  )
  writer.end_obj()

  // Font 4: Courier
  writer.start_obj(font_courier)
  writer.write_bytes(
    "<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>\n",
  )
  writer.end_obj()

  // Font 5: standard Adobe Simplified Chinese CID font (PDF 1.4 CMap).
  writer.start_obj(font_cjk)
  writer.write_bytes(
    "<< /Type /Font /Subtype /Type0 /BaseFont /STSong-Light-UniGB-UCS2-H /Encoding /UniGB-UCS2-H /DescendantFonts [" +
    font_cjk_descendant.to_string() +
    " 0 R] /ToUnicode " +
    font_to_unicode.to_string() +
    " 0 R >>\n",
  )
  writer.end_obj()

  writer.start_obj(font_cjk_descendant)
  writer.write_bytes(
    "<< /Type /Font /Subtype /CIDFontType0 /BaseFont /STSong-Light /CIDSystemInfo << /Registry (Adobe) /Ordering (GB1) /Supplement 4 >> /FontDescriptor " +
    font_cjk_descriptor.to_string() +
    " 0 R /DW 1000 >>\n",
  )
  writer.end_obj()

  writer.start_obj(font_cjk_descriptor)
  writer.write_bytes(
    "<< /Type /FontDescriptor /FontName /STSong-Light /Flags 6 /FontBBox [-25 -254 1000 880] /ItalicAngle 0 /Ascent 880 /Descent -254 /CapHeight 737 /StemV 58 /StemH 91 >>\n",
  )
  writer.end_obj()

  let to_unicode_cmap = unicode_to_unicode_cmap()
  writer.start_obj(font_to_unicode)
  writer.write_bytes(
    "<< /Length " +
    @unicode.to_utf8_bytes(to_unicode_cmap).length().to_string() +
    " >>\nstream\n" +
    to_unicode_cmap +
    "\nendstream\n",
  )
  writer.end_obj()

  // Cross-reference table (xref)
  let xref_offset = writer.byte_count
  let total_objs = font_to_unicode
  writer.write_bytes("xref\n")
  writer.write_bytes("0 " + (total_objs + 1).to_string() + "\n")
  writer.write_bytes("0000000000 65535 f \n")
  for i = 0; i < total_objs; i = i + 1 {
    let off_str = format_offset(writer.offsets[i])
    writer.write_bytes(off_str + " 00000 n \n")
  }

  // Trailer
  writer.write_bytes(
    "trailer\n<< /Size " +
    (total_objs + 1).to_string() +
    " /Root 1 0 R >>\nstartxref\n" +
    xref_offset.to_string() +
    "\n%%EOF\n",
  )

  writer.buf.to_string()
}

///|
fn hex_to_rgb(hex : String) -> (Double, Double, Double) {
  let clean = if hex.has_prefix("#") {
    hex[1:hex.length()].to_owned()
  } else {
    hex
  }
  if clean.length() == 6 {
    let r_high = hex_val(clean[0].to_int().unsafe_to_char())
    let r_low = hex_val(clean[1].to_int().unsafe_to_char())
    let g_high = hex_val(clean[2].to_int().unsafe_to_char())
    let g_low = hex_val(clean[3].to_int().unsafe_to_char())
    let b_high = hex_val(clean[4].to_int().unsafe_to_char())
    let b_low = hex_val(clean[5].to_int().unsafe_to_char())
    let r = (r_high * 16 + r_low).to_double() / 255.0
    let g = (g_high * 16 + g_low).to_double() / 255.0
    let b = (b_high * 16 + b_low).to_double() / 255.0
    (r, g, b)
  } else {
    (0.1, 0.1, 0.1)
  }
}

///|
fn hex_val(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - 48
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 97 + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 65 + 10
  } else {
    0
  }
}

///|
/// Encode page layout boxes into PDF vector drawing operators
fn encode_page_stream(sb : StringBuilder, page : @layout.PageLayout) -> Unit {
  let page_h = page.height

  for b in page.boxes {
    match b.kind {
      @layout.BoxKind::Text(text, font_size, color_hex, weight) => {
        let (r, g, b_val) = hex_to_rgb(color_hex)
        let initial_font = pdf_font_tag(weight, false)
        // PDF y-coordinates run upwards from bottom
        let pdf_y = page_h - b.rect.y - font_size * 0.85

        sb.write_string("BT\n")
        sb.write_string(
          r.to_string() +
          " " +
          g.to_string() +
          " " +
          b_val.to_string() +
          " rg\n",
        )
        sb.write_string(initial_font + " " + font_size.to_string() + " Tf\n")
        sb.write_string(
          b.rect.x.to_string() + " " + pdf_y.to_string() + " Td\n",
        )
        ignore(append_pdf_text_runs(sb, text, font_size, weight, initial_font))
        sb.write_string("ET\n")
      }
      @layout.BoxKind::RectFill(w, h, fill_hex, _radius) => {
        let (r, g, b_val) = hex_to_rgb(fill_hex)
        let pdf_y = page_h - b.rect.y - h
        sb.write_string(
          r.to_string() +
          " " +
          g.to_string() +
          " " +
          b_val.to_string() +
          " rg\n",
        )
        sb.write_string(
          b.rect.x.to_string() +
          " " +
          pdf_y.to_string() +
          " " +
          w.to_string() +
          " " +
          h.to_string() +
          " re f\n",
        )
      }
      @layout.BoxKind::RectStroke(w, h, stroke_hex, stroke_width) => {
        let (r, g, b_val) = hex_to_rgb(stroke_hex)
        let pdf_y = page_h - b.rect.y - h
        sb.write_string(stroke_width.to_string() + " w\n")
        sb.write_string(
          r.to_string() +
          " " +
          g.to_string() +
          " " +
          b_val.to_string() +
          " RG\n",
        )
        sb.write_string(
          b.rect.x.to_string() +
          " " +
          pdf_y.to_string() +
          " " +
          w.to_string() +
          " " +
          h.to_string() +
          " re s\n",
        )
      }
      @layout.BoxKind::Line(x1, y1, x2, y2, stroke_hex, stroke_width) => {
        let (r, g, b_val) = hex_to_rgb(stroke_hex)
        let pdf_y1 = page_h - y1
        let pdf_y2 = page_h - y2
        sb.write_string(stroke_width.to_string() + " w\n")
        sb.write_string(
          r.to_string() +
          " " +
          g.to_string() +
          " " +
          b_val.to_string() +
          " RG\n",
        )
        sb.write_string(x1.to_string() + " " + pdf_y1.to_string() + " m\n")
        sb.write_string(x2.to_string() + " " + pdf_y2.to_string() + " l S\n")
      }
      @layout.BoxKind::Circle(radius, fill_hex, stroke_hex, stroke_width) => {
        let cx = b.rect.x + radius
        let cy = page_h - (b.rect.y + radius)
        let k = radius * 0.5522847498 // Bézier constant for circle approximation

        if fill_hex.length() > 0 {
          let (r, g, b_val) = hex_to_rgb(fill_hex)
          sb.write_string(
            r.to_string() +
            " " +
            g.to_string() +
            " " +
            b_val.to_string() +
            " rg\n",
          )
        }
        if stroke_hex.length() > 0 {
          let (sr, sg, sb_val) = hex_to_rgb(stroke_hex)
          sb.write_string(stroke_width.to_string() + " w\n")
          sb.write_string(
            sr.to_string() +
            " " +
            sg.to_string() +
            " " +
            sb_val.to_string() +
            " RG\n",
          )
        }

        // 4 cubic Bézier curve segments constructing the circle
        sb.write_string(
          (cx + radius).to_string() + " " + cy.to_string() + " m\n",
        )
        sb.write_string(
          (cx + radius).to_string() +
          " " +
          (cy + k).to_string() +
          " " +
          (cx + k).to_string() +
          " " +
          (cy + radius).to_string() +
          " " +
          cx.to_string() +
          " " +
          (cy + radius).to_string() +
          " c\n",
        )
        sb.write_string(
          (cx - k).to_string() +
          " " +
          (cy + radius).to_string() +
          " " +
          (cx - radius).to_string() +
          " " +
          (cy + k).to_string() +
          " " +
          (cx - radius).to_string() +
          " " +
          cy.to_string() +
          " c\n",
        )
        sb.write_string(
          (cx - radius).to_string() +
          " " +
          (cy - k).to_string() +
          " " +
          (cx - k).to_string() +
          " " +
          (cy - radius).to_string() +
          " " +
          cx.to_string() +
          " " +
          (cy - radius).to_string() +
          " c\n",
        )
        sb.write_string(
          (cx + k).to_string() +
          " " +
          (cy - radius).to_string() +
          " " +
          (cx + radius).to_string() +
          " " +
          (cy - k).to_string() +
          " " +
          (cx + radius).to_string() +
          " " +
          cy.to_string() +
          " c\n",
        )

        if fill_hex.length() > 0 && stroke_hex.length() > 0 {
          sb.write_string("B\n")
        } else if fill_hex.length() > 0 {
          sb.write_string("f\n")
        } else {
          sb.write_string("S\n")
        }
      }
      @layout.BoxKind::Container(children) =>
        for child in children {
          let dummy_page : @layout.PageLayout = {
            width: page.width,
            height: page.height,
            boxes: [child],
          }
          encode_page_stream(sb, dummy_page)
        }
    }
  }
}

///|
fn append_pdf_text_runs(
  sb : StringBuilder,
  text : String,
  font_size : Double,
  weight : String,
  current_font : String,
) -> String {
  let mut active_font = current_font
  if text.length() == 0 {
    active_font = write_pdf_text_run(
      sb, "", font_size, weight, false, active_font,
    )
    return active_font
  }

  let mut run = StringBuilder()
  let mut run_active = false
  let mut run_is_unicode = false
  let mut i = 0
  while i < text.length() {
    let mut unit = text.code_unit_at(i).to_int()
    let mut consumed = 1
    if unit >= 55296 && unit <= 56319 {
      unit = 63
      if i + 1 < text.length() &&
        text.code_unit_at(i + 1) >= 56320 &&
        text.code_unit_at(i + 1) <= 57343 {
        consumed = 2
      }
    } else if unit >= 56320 && unit <= 57343 {
      unit = 63
    }

    let is_unicode = match pdf_winansi_byte(unit) {
      Some(_) => false
      None => true
    }
    if run_active && is_unicode != run_is_unicode {
      active_font = write_pdf_text_run(
        sb,
        run.to_string(),
        font_size,
        weight,
        run_is_unicode,
        active_font,
      )
      run = StringBuilder()
      run_active = false
    }
    run.write_char(unit.unsafe_to_char())
    run_active = true
    run_is_unicode = is_unicode
    i = i + consumed
  }

  if run_active {
    active_font = write_pdf_text_run(
      sb,
      run.to_string(),
      font_size,
      weight,
      run_is_unicode,
      active_font,
    )
  }
  active_font
}

///|
fn write_pdf_text_run(
  sb : StringBuilder,
  text : String,
  font_size : Double,
  weight : String,
  is_unicode : Bool,
  current_font : String,
) -> String {
  let font_tag = pdf_font_tag(weight, is_unicode)
  let text_operand = if is_unicode {
    encode_pdf_unicode_hex(text)
  } else if has_non_ascii_code_unit(text) {
    encode_pdf_winansi_hex(text)
  } else {
    "(" + escape_pdf_string(text) + ")"
  }
  if font_tag != current_font {
    sb.write_string(font_tag + " " + font_size.to_string() + " Tf\n")
  }
  sb.write_string(text_operand + " Tj\n")
  font_tag
}

///|
fn has_non_ascii_code_unit(text : String) -> Bool {
  for i = 0; i < text.length(); i = i + 1 {
    if text.code_unit_at(i) > 127 {
      return true
    }
  }
  false
}

///|
/// Return the byte used by PDF's WinAnsiEncoding for supported Unicode scalars.
fn pdf_winansi_byte(codepoint : Int) -> Int? {
  if (codepoint >= 0 && codepoint <= 127) ||
    (codepoint >= 160 && codepoint <= 255) {
    return Some(codepoint)
  }
  match codepoint {
    8364 => Some(128) // EURO SIGN
    8218 => Some(130) // SINGLE LOW-9 QUOTATION MARK
    402 => Some(131) // LATIN SMALL LETTER F WITH HOOK
    8222 => Some(132) // DOUBLE LOW-9 QUOTATION MARK
    8230 => Some(133) // HORIZONTAL ELLIPSIS
    8224 => Some(134) // DAGGER
    8225 => Some(135) // DOUBLE DAGGER
    710 => Some(136) // MODIFIER LETTER CIRCUMFLEX ACCENT
    8240 => Some(137) // PER MILLE SIGN
    352 => Some(138) // LATIN CAPITAL LETTER S WITH CARON
    8249 => Some(139) // SINGLE LEFT-POINTING ANGLE QUOTATION MARK
    338 => Some(140) // LATIN CAPITAL LIGATURE OE
    381 => Some(142) // LATIN CAPITAL LETTER Z WITH CARON
    8216 => Some(145) // LEFT SINGLE QUOTATION MARK
    8217 => Some(146) // RIGHT SINGLE QUOTATION MARK
    8220 => Some(147) // LEFT DOUBLE QUOTATION MARK
    8221 => Some(148) // RIGHT DOUBLE QUOTATION MARK
    8226 => Some(149) // BULLET
    8211 => Some(150) // EN DASH
    8212 => Some(151) // EM DASH
    732 => Some(152) // SMALL TILDE
    8482 => Some(153) // TRADE MARK SIGN
    353 => Some(154) // LATIN SMALL LETTER S WITH CARON
    8250 => Some(155) // SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
    339 => Some(156) // LATIN SMALL LIGATURE OE
    382 => Some(158) // LATIN SMALL LETTER Z WITH CARON
    376 => Some(159) // LATIN CAPITAL LETTER Y WITH DIAERESIS
    _ => None
  }
}

///|
fn encode_pdf_winansi_hex(s : String) -> String {
  let digits = "0123456789ABCDEF"
  let sb = StringBuilder()
  for i = 0; i < s.length(); i = i + 1 {
    let byte = match pdf_winansi_byte(s.code_unit_at(i).to_int()) {
      Some(value) => value
      None => 63
    }
    sb.write_char(digits[(byte >> 4) & 15].to_int().unsafe_to_char())
    sb.write_char(digits[byte & 15].to_int().unsafe_to_char())
  }
  "<" + sb.to_string() + ">"
}

///|
fn pdf_font_tag(weight : String, is_unicode : Bool) -> String {
  if is_unicode {
    "/F5"
  } else {
    match weight {
      "bold" => "/F2"
      "italic" => "/F3"
      "monospace" => "/F4"
      _ => "/F1"
    }
  }
}
