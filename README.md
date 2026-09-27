# moon-typst

<div align="center">

**A Pure MoonBit Parser, Layout Engine, and SVG/PDF/HTML Renderer for a Typst-Style Markup Subset.**

基于 MoonBit 实现的 Typst 风格语法子集解析、盒模型排版与多后端（SVG / PDF 1.4 / HTML5）渲染引擎。

[![CI](https://github.com/Lxxbv/moon-typst/actions/workflows/ci.yml/badge.svg)](https://github.com/Lxxbv/moon-typst/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Target](https://img.shields.io/badge/Target-Wasm--GC%20%7C%20Native%20%7C%20JS-success.svg)](https://www.moonbitlang.com/)
[![Mooncakes](https://img.shields.io/badge/Mooncakes-Lxxbv%2Fmoon__typst-orange.svg)](https://mooncakes.io/)

[English](#english) | [中文说明](#中文说明)

</div>

---

## 中文说明

### 🌟 项目背景与生态价值

[Typst](https://github.com/typst/typst) 是现代排版系统。MoonBit 支持将同一代码编译到 Native、JavaScript 和 WebAssembly GC 目标；本项目在这些目标上实现解析、排版与渲染功能。

本项目参考 Typst 公开的标记语法与文档工具链思路，解析器、MoonBit AST、求值、排版和渲染实现均由本仓库独立编写。它实现的是 README 所列的 Typst 风格语法子集，并非完整 Typst 编译器；上游 Typst 仓库使用 Apache-2.0 许可证，本项目也以 Apache-2.0 发布。

`moon-typst` 提供以下功能：
- **MoonBit 源码实现**：解析、排版与渲染模块以 MoonBit 编写，可构建到 `wasm-gc`、`js` 以及 `native` 目标。
- **文档处理管线**：涵盖源码位置跟踪（Span）、词法分析、递归下降解析、脚本求值、盒模型排版，以及 SVG 1.1、PDF 1.4 和 HTML5 输出。
- **可复现实验入口**：`benchmarks/pipeline_test.mbt` 提供分阶段和端到端编译基准，以下列出运行命令、测量口径与实测环境。

---

### 🏗️ 系统架构设计

```mermaid
flowchart LR
    A["Typst 源码 (.typ)"] --> B["词法分析器 (parser/lexer)"]
    B --> C["Token 流 + 源码位置 Span"]
    C --> D["递归下降解析器 (parser/parser)"]
    D --> E["文档 AST (core.Doc)"]
    E --> F["脚本求值与级联样式 (eval)"]
    F --> G["流式几何盒模型引擎 (layout)"]
    G --> H["几何盒模型树 (LayoutBox)"]
    H --> I["PDF 1.4 二进制生成器 (render/pdf)"]
    H --> J["SVG 矢量渲染器 (render/svg)"]
    E --> K["HTML5 语义渲染器 (render/html)"]
    I --> L["标准 PDF 文件 (.pdf)"]
    J --> M["自包含矢量图 (.svg)"]
    K --> N["响应式网页 (.html)"]
```

#### 核心包模块职责：
1. **`core` (核心领域模型与 AST)**：
   - 定义不可变文档抽象语法树（`Doc`、`Block`、`Inline`、`MathExpr`）。
   - 度量单位系统 `Length`（支持 `pt`、`mm`、`cm`、`in`、`em`、`fr` 弹性比例与百分比 `%`）。
   - 颜色系统 `Color`（支持 `#RRGGBB` 十六进制、RGB、HSL 与标准颜色名称）。
   - 图形节点（`Rect`、`Circle`、`Line`）、网格布局（`Grid`）、脚注（`Footnote`）与图表（`Figure`）。
2. **`diag` (源码诊断与高亮报错)**：
   - 源码位置跨度（`Pos`、`Span`）。
   - 多级别诊断系统（`Error`、`Warning`、`Hint`、`Info`）。
   - 类似 Rustc/Clang 的 ANSI 彩色终端诊断报告器，带有代码切片、行号、下划波浪线及智能修复提示。
3. **`eval` (Typst 脚本演算与运行时环境)**：
   - 动态值系统 `Val`（数值、字符串、布尔、颜色、长度、几何形状、数组、字典）。
   - 词法作用域管理（`Scope`、`Evaluator`）与变量遮蔽机制。
   - 级联样式规则 `#set`（如 `#set text(size: ..., fill: ...)` 与 `#set page(columns: ...)`）。
   - 常用内置排版函数分发（`#rect`、`#circle`、`#grid`、`#align` 等）。
4. **`parser` (词法与语法分析)**：
   - 零回溯词法分析器（`Lexer`），原生兼容 Windows CRLF 与 UTF-8 BOM。
   - 递归下降语法解析器（`Parser`），解析复杂行内、块级标记、哈希表达式调用与数学语法。
   - 复杂数学公式语法解析：多行矩阵 `mat(...)`、列向量 `vec(...)`、音标重音符 `hat`、`tilde`、`dot`、`bar`、大型求和与积分记号 `sum`、`int`。
5. **`layout` (空间排版与盒模型计算)**：
   - 多列页面流（Multi-column Layout）、字宽与行高自适应折行计算。
   - 二维数学基准线平衡算法（根式延长线、分式上下对齐、矩阵格子行列对齐）。
   - 几何盒抽象（`LayoutBox`、`PageLayout`、`DocumentLayout`）。
6. **`render` (多格式矢量后端)**：
   - `pdf.mbt`：MoonBit 实现的 PDF 1.4 生成器，支持间接对象序列化、xref 交叉引用表、Catalog/Pages 树结构、标准 Type1 字体及 PDF 绘制操作流。WinAnsi 可编码的拉丁字符（包括常见重音字母）使用对应 Type1 字体；BMP 非 ASCII 文本其余部分按 Adobe-GB1 的 `UniGB-UCS2-H` CMap 编码，简体中文仅在该字符集覆盖范围内保证字形，其他未覆盖字符可能显示为空白。混排文本按字体分段，中文使用常规字重。字体不内嵌，显示依赖阅读器的字体资源或替代字体。补充平面字符在 PDF 输出中以 `?` 代替。
   - `svg.mbt`：生成符合 W3C 标准、支持自包含字体样式与平滑线条的 SVG 1.1 矢量图。
   - `html.mbt`：生成语义化现代科技风响应式 HTML5 网页，内置自适应排版 CSS。
7. **`cmd/main` (跨平台命令行编译工具)**：
   - 提供命令行工具，支持参数解析、格式推导与彩色错误诊断输出。

---

### 🚀 语法与排版特性全景图

| 语法特性 | Typst 标记写法 | 支持状态 | 渲染输出表现 |
| :--- | :--- | :---: | :--- |
| **多级标题** | `= 一级标题`, `== 二级标题`, `=== 三级标题` | 已实现 | 层级字体缩放、下划线隔断、自动排版间距 |
| **行内样式** | `*粗体*`, `_斜体_`, `` `行内代码` `` | 已实现 | 字体加粗/倾斜、等宽字符盒、HTML 语义化映射 |
| **超链接** | `[文字](https://...)` | 已实现 | 可点击链接、高亮样式与悬停下划线 |
| **代码块** | ` ```moonbit ... ``` ` | 已实现 | 等宽字体盒、代码底色块、保留缩进与换行 |
| **列表排版** | `- 无序项`, `+ 有序项` | 已实现 | 自动排布项目圆点、自动编号递增（1., 2., ...） |
| **高等数学** | `$ frac(a, b) $`, `$ sqrt(x) $`, `$ x^2_i $` | 已实现 | 居中公式块、公式斜体、分数线对齐、根号上横线 |
| **矩阵与向量** | `$ mat(1, 2; 3, 4) $`, `$ vec(x, y, z) $` | 已实现 | 动态行列间距计算、数学括号包络与网格排列 |
| **算子与重音** | `$ sum $, $ int $, $ hat(x) $, $ tilde(y) $` | 已实现 | 大型上下标基准线定位、字母顶置符号修饰 |
| **几何图形** | `#rect(...)`, `#circle(...)` | 已实现 | 自定义填充色、边框宽度、圆角半径矢量绘制 |
| **网格布局** | `#grid(columns: (1fr, 1fr), ...)` | 已实现 | 弹性比例与固定尺寸分栏排版 |
| **级联样式** | `#set text(size: 12pt)`, `#set page(...)` | 已实现 | 动态修改上下文默认字号、颜色、多栏列数 |
| **多目标输出** | `PDF 1.4`, `SVG 1.1`, `HTML5` | 已实现 | 对应格式的文档输出 |

---

### 管道表格语法

每行用竖线分隔单元格。首行后紧跟分隔行时，首行作为表头；冒号控制列对齐（`:---` 左对齐，`:---:` 居中，`---:` 右对齐）。行首和行尾的竖线可省略，短行会补为空单元格。为避免把带竖线的普通句子识别成表格，无外框表格需至少有两行连续且列数相同的数据，或使用表头分隔行；单行表格请保留外侧竖线。

```typst
| Target | Status | Notes |
| :--- | :---: | ---: |
| native | supported | SVG/PDF/HTML |
| js | supported | HTML |
```

这是有限的管道表格语法，并非完整 Typst 表格实现；目前不支持转义竖线、合并单元格、嵌套表格或分页。

---

### 📦 快速上手与使用指南

#### 1. 作为库引入项目
在您的 MoonBit 项目根目录下执行：
```bash
moon add Lxxbv/moon_typst
```

在 `moon.pkg` 中引入所需模块：
```json
{
  "import": [
    "Lxxbv/moon_typst/core",
    "Lxxbv/moon_typst/diag",
    "Lxxbv/moon_typst/eval",
    "Lxxbv/moon_typst/parser",
    "Lxxbv/moon_typst/layout",
    "Lxxbv/moon_typst/render"
  ]
}
```

在 MoonBit 代码中调用编译管线：
```moonbit
import "Lxxbv/moon_typst/parser" as @parser
import "Lxxbv/moon_typst/layout" as @layout
import "Lxxbv/moon_typst/render" as @render
import "Lxxbv/moon_typst/core" as @core

pub fn compile_typst(source : String) -> Unit {
  // 1. 解析源码为 AST
  let doc = @parser.parse_typst(source)
  
  // 2. 配置样式上下文并计算流式盒模型
  let style = @core.StyleContext::default()
  let engine = @layout.LayoutEngine::new(style)
  let page = engine.layout_doc(doc)
  
  // 3. 生成 Adobe PDF 1.4 二进制数据
  let pdf_data = @render.render_pdf(page)
  
  // 4. 生成矢量 SVG 图形
  let svg_data = @render.render_svg(page)
  
  // 5. 生成语义化 HTML5 页面
  let html_data = @render.render_html(doc)
}
```

#### 2. 使用命令行工具 (CLI)
直接编译可执行文件：
```bash
moon build
```

通过 CLI 进行多格式渲染：
```bash
# 1. 编译为标准 PDF 1.4 二进制文件
moon run cmd/main -- examples/paper.typ -p -o examples/paper.pdf

# 生成包含中文文本的 PDF 示例
moon run cmd/main -- examples/chinese.typ -p -o examples/chinese.pdf

# 2. 编译为矢量 SVG 图形
moon run cmd/main -- examples/paper.typ --svg -o examples/paper.svg

# 3. 编译为响应式 HTML5 网页
moon run cmd/main -- examples/paper.typ --html -o examples/paper.html

# 4. 查看所有选项与帮助信息
moon run cmd/main -- --help
```

---

### 🔬 官方真实用例套件

本项目在 `examples/` 目录下提供学术论文、幻灯片演讲、简历与报告示例：

1. **学术论文 (`examples/paper.typ`)**：
   - 包含多级标题、数学公式推导（$E=mc^2$、分式、根式）、系统架构列表。
   - 产物输出：[`paper.pdf`](examples/paper.pdf), [`paper.svg`](examples/paper.svg), [`paper.html`](examples/paper.html)。
2. **高等数学论文 (`examples/multi_column_paper.typ`)**：
   - 包含多维矩阵 `mat(a, b; c, d)`、三维向量 `vec(x, y, z)`、求和算子 `sum`、重音符号 `hat(theta)`、代码块与多格式对比。
   - 产物输出：[`multi_column_paper.pdf`](examples/multi_column_paper.pdf), [`multi_column_paper.svg`](examples/multi_column_paper.svg), [`multi_column_paper.html`](examples/multi_column_paper.html)。
3. **幻灯片演示文稿 (`examples/presentation.typ`)**：
   - 包含分页演讲卡片、彩色横幅、三列式架构分解与命令行快速指引。
   - 产物输出：[`presentation.pdf`](examples/presentation.pdf), [`presentation.svg`](examples/presentation.svg), [`presentation.html`](examples/presentation.html)。
4. **技术评估报告 (`examples/report.typ`)** 与 **专业简历 (`examples/resume.typ`)**。
5. **中文 PDF 示例 (`examples/chinese.typ`)**：展示简体中文 CID 字体路径及其字体替代边界。

---

### ⚡ 性能基准测试 (Micro-benchmarks)

从模块根目录运行以下命令；每个目标单独运行并保存完整原始输出：

```bash
moon version --all
moon bench benchmarks --target native --release --deny-warn
moon bench benchmarks --target wasm-gc --release --deny-warn
moon bench benchmarks --target js --release --deny-warn
```

`benchmarks/pipeline_test.mbt` 同时包含分阶段基准和端到端内存编译基准。端到端样例包含两段中文长文本、Latin/重音字符和表格；每次计时包括诊断器与样式上下文初始化、解析，以及对应输出路径。SVG/PDF 还包括排版，HTML 直接从 AST 生成语义化输出。测试排除了 CLI 冷启动、参数解析、磁盘读取、终端日志和文件写入。

2026-09-27 在 Windows 11（build 26200）、13th Gen Intel Core i7-13620H、MoonBit `moon 0.1.20260915` / `moonc v0.10.13+cbb11c36f` 上运行，10 个测量样本的均值如下：

| 目标 | HTML | SVG | PDF |
| --- | ---: | ---: | ---: |
| native | 48.36 µs | 132.91 µs | 283.00 µs |
| wasm-gc | 15.13 µs | 49.63 µs | 140.18 µs |
| js | 16.28 µs | 48.59 µs | 291.81 µs |

这组固定输入与环境下的内存编译均值低于 1 ms；它不代表其他文档、设备或包含进程启动和文件 I/O 的 CLI 用时。`@bench.T::bench` 自动校准每组迭代次数；根据 [MoonBit benchmark 文档](https://docs.moonbitlang.com/en/latest/language/benchmarks.html)，默认展示 10 组测量，但没有单独保证预热阶段。引用基准结果时，请同时记录 Git 提交、完整命令、工具链、操作系统、CPU、运行环境、日期和原始输出。分阶段结果仍由同一文件中的 `parse`、`layout`、`html`、`svg` 和 `pdf` 项提供。

---

<br/>

## English

### 🌟 Project Overview & Ecosystem Value

[Typst](https://github.com/typst/typst) is a modern typesetting system. MoonBit lets this project compile its parser, layout engine, and renderers for Native, JavaScript, and WebAssembly GC targets.

`moon-typst` independently implements a supported subset of Typst-style markup in MoonBit: lexical scanner, recursive descent parser, runtime evaluation environment, spatial box-model layout engine, and SVG 1.1, PDF 1.4, and HTML5 renderers. It is not a full Typst compiler. The module builds for Native, JavaScript, and WebAssembly GC targets. The implementation is inspired by Typst's public syntax and toolchain design; the upstream Typst repository uses Apache-2.0, and this project is also released under Apache-2.0.

### 📐 Features
- **MoonBit Implementation**: Parser, layout, and renderer source is written in MoonBit.
- **Triple Vector Targets**:
  - **Adobe PDF 1.4**: Direct binary serializer with xref tables, Type1 fonts, and vector drawing operators. WinAnsi-encodable Latin characters, including common accented letters, use the matching Type1 font. Other BMP non-ASCII text uses Adobe-GB1's `UniGB-UCS2-H` CMap; Simplified Chinese is guaranteed only within that collection's glyph coverage, and other uncovered characters may render blank. Mixed text is split by font; CJK uses a regular `STSong-Light` face. The font is not embedded, so rendering depends on reader font resources or substitution; supplementary Unicode characters become `?`.
  - **Scalable Vector Graphics (SVG 1.1)**: Clean vector elements and font metrics.
  - **Semantic HTML5**: Responsive CSS styling for web publishing.
- **Advanced Mathematical Typesetting**:
  - Fractions, square roots, sub/superscript.
  - Multi-dimensional matrices (`mat(1, 2; 3, 4)`), column vectors (`vec(x, y)`).
  - Accented characters (`hat(x)`, `tilde(y)`, `dot`, `bar`) and limit operators (`sum`, `int`).
- **Pipe Tables**: Pipe-delimited rows with optional outer pipes; a separator after the first row marks the header, and colons select left/center/right alignment. Short rows are padded. Unbordered tables need at least two consecutive rows with matching column counts, or a header separator; use outer pipes for a single-row table. Escaped pipes, merged cells, nested tables, and pagination are not supported.
- **Scripting & Evaluation Engine (`eval`)**:
  - Variable scopes, constant evaluation, and cascading `#set` rules (`text`, `page`).
- **Rich Terminal Diagnostics (`diag`)**:
  - Source span tracking, Rustc-style colorized diagnostic reporting with line numbers, code snippets, and hints.
- **Reproducible Benchmarks**: The [benchmark entry point](benchmarks/pipeline_test.mbt) measures individual stages and an in-memory parse/layout/render path for HTML, SVG, and PDF. The fixed Chinese-text sample measured below 1 ms on the documented Windows and MoonBit toolchain; this is a result for that fixture and machine, not a general performance guarantee. Measurements exclude CLI startup and file I/O. See the Chinese benchmark section for commands, exact means, and environment details.

---

### 🧪 Test & CI Coverage
- Unit tests across `core`, `diag`, `eval`, `parser`, `layout`, and `render`.
- GitHub Actions CI matrix testing on **Ubuntu**, **macOS**, and **Windows**.
- Strict formatting and all-target warning checks (`moon fmt --check`, `moon check --target all --deny-warn`, `moon test --target all --deny-warn`).

---

### 📄 License

Licensed under the [Apache-2.0 License](LICENSE).

Developed with ❤️ by **Lxxbv** for the 2026 September MoonBit Hackathon.
