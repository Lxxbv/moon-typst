= Markup Typography on WebAssembly

== Abstract

Modern document preparation systems demand both instant feedback and high typographical precision. While traditional systems like LaTeX provide rich typesetting capabilities, their compilation latency and complex dependencies hinder cloud-native interactive workflows. Typst introduced a modern syntax and incremental layout model.

In this work, we present *moon-typst*, a typographical compiler implemented in MoonBit. Its parser, box layout, and vector renderers can be measured separately with the checked-in benchmark.

== Mathematical Foundation

The vertical spacing distribution model follows standard typographical baseline kinetics:

$ E = m c^2 $

Furthermore, inline formulations such as $f(x) = sqrt(x^2 + 1)$ and fraction derivations:

$ frac(a + b, c + d) $

maintain harmonic font metrics and balanced baseline alignments across heterogeneous output devices.

== Architecture Overview

The system pipeline consists of three decoupled phases:

- Lexical Tokenization & Parsing: Recursive descent parser yielding lossless AST nodes
- Geometric Layout Engine: Bounding box calculation, font metric estimation, and page break partitioning
- Dual-Target Vector Renderer: SVG 1.1 vector paths and semantic HTML5 DOM structures

== Empirical Results

Run `moon bench benchmarks --target wasm-gc --release --deny-warn` and record the host, MoonBit version, and raw results before making WebAssembly performance comparisons.
