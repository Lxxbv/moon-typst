# Changelog

## 0.2.1

- Wrap long CJK text, Latin words, and oversized tokens within the available paragraph width.
- Preserve spaces across styled inline spans and wrap links, math, and footnote references when the remaining line width is insufficient.
- Keep inline formulas within the page edge by accounting for accent marks and upper or lower limits.
- Measure text by Unicode scalar values so supplementary characters do not count as two display glyphs in layout metrics.
- Add regression coverage for CJK and Latin line wrapping, supplementary text, and reproducible in-memory end-to-end benchmarks.
## 0.2.0

- Add PDF 1.4 Adobe-GB1 CID font output for BMP text, including covered Simplified Chinese characters.
- Split mixed Latin/CJK PDF text runs so each font uses its own character widths.
- Keep WinAnsi-encodable accented Latin text in its matching Type1 font.
- Fall back to `?` for supplementary Unicode characters in PDF output.
- Clarify that PDF glyph coverage outside Adobe-GB1 is not guaranteed.
- Clarify the supported Typst-style syntax subset and upstream inspiration.
- Pin and assert the CI MoonBit compiler version and add PDF CLI smoke examples.
