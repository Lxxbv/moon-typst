name = "Lxxbv/moon_typst"

version = "0.2.1"

readme = "README.md"

repository = "https://github.com/Lxxbv/moon-typst"

license = "Apache-2.0"

keywords = [
  "typst",
  "typesetting",
  "parser",
  "layout",
  "svg",
  "html",
  "pdf",
  "renderer",
]

description = "A lightweight MoonBit implementation of a supported Typst-style markup subset with parser, layout engine, and SVG/PDF/HTML renderers."

preferred_target = "wasm-gc"

warnings = "-implicit_impl_as_method-test_unqualified_package"

import {
  "moonbitlang/x@0.5.5",
}
