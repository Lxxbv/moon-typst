= Benchmark Protocol: moon-typst

== Document Metadata

Author: Infrastructure & Tooling Working Group
Date: September 2026
Version: 1.0.0

---

== Executive Summary

This report describes how to measure parsing, layout, and rendering for a fixed sample document. Results depend on the selected backend, host, and toolchain.

The benchmark entry point is `benchmarks/pipeline_test.mbt`. It measures each pipeline stage separately and does not measure file I/O, CLI startup, or an end-to-end compilation.

== Implementation Architecture

The core pipeline is written in 100% pure MoonBit without external C FFI bindings:

Run `moon bench benchmarks --target native --release --deny-warn` from the module root to collect native results.

Key features of this pipeline include:

+ A fixed source string for the parse stage
+ A parsed document prepared before layout and HTML measurements
+ A laid-out page prepared before SVG and PDF measurements

---

== Measurement Worksheet

Record the full command, target, MoonBit version, operating system, CPU, and raw benchmark output before reporting results. Each stage measures one operation on the checked-in sample input.

| Stage | Input | Timed operation | Output |
| :--- | :--- | :---: | ---: |
| Parse | Fixed source | `parse_typst` | Document AST |
| Layout | Prepared AST | `layout_doc` | Page layout |
| HTML | Prepared AST | `render_html` | HTML string |
| SVG | Prepared page | `render_svg` | SVG string |
| PDF | Prepared page | `render_pdf` | PDF string |

---

== Conclusion & Recommendations

Use the same input, target, toolchain, and host conditions when comparing runs. The stage timings cannot be added to claim CLI latency because setup and serialization differ from an end-to-end run.
