= MoonBit Typographical Compiler: Architecture & Features

== Slide 1: Introduction to moon-typst

*moon-typst* brings modern typographical typesetting to the MoonBit ecosystem.

- *Zero-FFI Pure MoonBit*: 100% portable across Native, JS, and WebAssembly targets
- *Sub-millisecond Compilation*: Incremental layout engine built for interactive documents
- *Multi-Target Rendering*: Seamless output to SVG, semantic HTML5, and standard PDF 1.4
- *Rich Mathematical Layout*: First-class support for fractions, square roots, matrices, and limits

== Slide 2: Mathematical Capabilities

Typesetting complex scientific formulas with pixel-perfect alignment:

$ frac(alpha + beta, gamma + delta) $

Multivariate transformations with matrix layouts:

$ mat(1, 0, 0; 0, 1, 0; 0, 0, 1) $

State vectors in 3D projection:

$ vec(u, v, w) $

== Slide 3: Architectural Pipeline

The internal pipeline consists of four modular packages:

- *core*: Abstract syntax tree, color representations, and length unit conversions
- *diag*: Source span tracking, diagnostic error collection, and colorized terminal reports
- *eval*: Lexical scoping, variable environments, and cascading style rules
- *parser*: Fast recursive descent lexer and token stream analyzer
- *layout*: Spatial bounding box calculations, text measurement, and table layout
- *render*: SVG vector emitter, HTML5 document generator, and PDF 1.4 binary serializer

== Slide 4: Getting Started

Compile any Typst document directly using the CLI:

```bash
# Render to vector SVG
typst-render presentation.typ -o presentation.svg

# Render to standard PDF 1.4
typst-render presentation.typ -p -o presentation.pdf

# Render to semantic HTML5
typst-render presentation.typ --html -o presentation.html
```

Empowering next-generation cloud and WebAssembly document authoring!
