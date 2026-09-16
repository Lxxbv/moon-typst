///|
/// Pure MoonBit PDF 1.4 vector document generator
/// Compiles document box geometry into standard, self-contained PDF binaries.

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
  { buf: StringBuilder(), offsets: [], byte_count: 0 }
}

///|
fn PdfWriter::write_bytes(self : PdfWriter, s : String) -> Unit {
  self.buf.write_string(s)
  self.byte_count = self.byte_count + s.length()
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
      stream_str.length().to_string() +
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

  // Cross-reference table (xref)
  let xref_offset = writer.byte_count
  let total_objs = font_courier
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
        let font_tag = match weight {
          "bold" => "/F2"
          "italic" => "/F3"
          "monospace" => "/F4"
          _ => "/F1"
        }
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
        sb.write_string(font_tag + " " + font_size.to_string() + " Tf\n")
        sb.write_string(
          b.rect.x.to_string() + " " + pdf_y.to_string() + " Td\n",
        )
        sb.write_string("(" + escape_pdf_string(text) + ") Tj\n")
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
        sb.write_string((cx + radius).to_string() + " " + cy.to_string() + " m\n")
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
