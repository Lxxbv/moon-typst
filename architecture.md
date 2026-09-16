# Architecture Specification: moon-typst (v0.2.0)

`moon-typst` 是一个纯 MoonBit 实现的轻量级、工业级 Typst 标记语言编译器、盒模型空间排版与多后端（SVG / PDF 1.4 / HTML5）矢量渲染引擎。本文档详细描述其系统架构、分层设计、核心数据流与接口规范。

---

## 1. 整体架构编译与渲染流水线

`moon-typst` 采用经典的多阶段编译器前端与流式矢量排版管线：

```text
+-------------------+
|  Typst Text .typ  |
+-------------------+
          |
          v
+-------------------+  (parser/lexer.mbt & diag/span.mbt)
|   Token Stream    |  词法分析、源码位置 Span 跟踪、高亮报错
+-------------------+
          |
          v
+-------------------+  (parser/parser.mbt & parser/math_helper.mbt)
|   Document AST    |  递归下降解析：Doc, Block, Inline, MathExpr (矩阵/向量/重音)
+-------------------+
          |
          v
+-------------------+  (eval/env.mbt, eval/value.mbt, eval/builtins.mbt)
| Evaluated Context |  词法作用域 Scope、级联 #set 规则、排版内建函数求值
+-------------------+
          |
          v
+-------------------+  (layout/engine.mbt & layout/box.mbt)
| Layout Box Tree   |  多栏/单栏排版、空间盒几何测量、折行、基准线平衡
+-------------------+
          |
    +-----+-----+----------------+
    |           |                |
    v           v                v
+-------+   +--------+      +----------+
|  SVG  |   |  HTML  |      |  PDF 1.4 |  (render/svg.mbt, html.mbt, pdf.mbt)
+-------+   +--------+      +----------+
```

---

## 2. 模块划分与包拓扑结构

全工程共包含 **7 个功能包**、**25 个 `.mbt` 源码文件**，总计 **5,223 行** 100% 纯 MoonBit 原生代码：

```text
moon-typst/
├── moon.mod               # 模块配置 (name = "Lxxbv/moon_typst")
├── core/                  # 核心数据模型、度量单位与不可变 AST
│   ├── moon.pkg
│   ├── ast.mbt            # Doc, Block, Inline, MathExpr, ShapeKind, Grid
│   ├── length.mbt         # Length (Pt, Mm, Cm, In, Em, Fr, Percent)
│   ├── color.mbt          # Color (Hex, Rgb, Hsl, Named)
│   └── ast_test.mbt       # 核心模型与单位转换测试
├── diag/                  # 源码位置定位与彩色终端诊断器
│   ├── moon.pkg
│   ├── span.mbt           # Pos, Span 跨度计算与包含判定
│   ├── diagnostic.mbt     # Diagnostic (Error, Warning, Hint), DiagnosticReporter
│   └── diag_test.mbt      # 诊断收集与 ANSI 格式化测试
├── eval/                  # 脚本演算、动态值系统与级联样式
│   ├── moon.pkg
│   ├── value.mbt          # Val 动态数据类型与转换
│   ├── env.mbt            # Scope, Evaluator, apply_set_rule (#set 规则)
│   ├── builtins.mbt       # #rect, #circle, #grid 等排版内置函数求值
│   └── eval_test.mbt      # 作用域求值与级联规则测试
├── parser/                # 词法扫描器与无回溯递归下降语法解析器
│   ├── moon.pkg
│   ├── token.mbt          # Token 枚举
│   ├── lexer.mbt          # 纯 MoonBit 词法状态机 (支持 CRLF 与 UTF-8 BOM)
│   ├── parser.mbt         # 递归下降解析、哈希调用与块级/行内构建
│   ├── math_helper.mbt    # 矩阵 (mat)、列向量 (vec)、音标重音 (hat/tilde)、极限 (sum/int)
│   ├── lexer_test.mbt     # 词法切分测试
│   └── parser_test.mbt    # 语法解析测试
├── layout/                # 排版引擎与几何盒模型计算
│   ├── moon.pkg
│   ├── box.mbt            # Rect, LayoutBox, BoxKind, PageLayout, DocumentLayout
│   ├── engine.mbt         # 流式多列排版、二维数学排布与几何分配
│   └── layout_test.mbt    # 排版盒模型几何测试
├── render/                # 多格式矢量后端生成器
│   ├── moon.pkg
│   ├── pdf.mbt            # 纯 MoonBit Adobe PDF 1.4 二进制生成器 (xref/Type1/流)
│   ├── svg.mbt            # W3C 标准 SVG 1.1 矢量图生成器
│   ├── html.mbt           # 现代科技风语义化 HTML5 生成器
│   └── render_test.mbt    # 渲染器综合断言测试
├── cmd/                   # 跨平台命令行编译工具
│   └── main/
│       ├── moon.pkg
│       └── main.mbt       # CLI 入口 (支持 -p/--pdf, --svg, --html, 彩色诊断)
└── examples/              # 官方多领域真实复现用例
    ├── paper.typ          # 学术论文范例
    ├── multi_column_paper.typ # 矩阵/向量/多列学术范例
    ├── presentation.typ   # 幻灯片演讲范例
    ├── resume.typ         # 专业求职简历
    └── report.typ         # 工业技术基准测试报告
```

### 依赖关系图：
- `cmd/main` -> `render`, `layout`, `eval`, `parser`, `diag`, `core`
- `render` -> `layout`, `core`
- `layout` -> `core`
- `eval` -> `diag`, `core`
- `parser` -> `diag`, `core`
- `diag` -> 无项目内依赖
- `core` -> 无项目内依赖

---

## 3. 核心数据结构设计

### 3.1 Document AST (`core/ast.mbt`)

```moonbit
// 块级元素
pub enum Block {
  Heading(Int, Array[Inline])
  Paragraph(Array[Inline])
  List(Bool, Array[Array[Inline]])
  CodeBlock(String, String)
  MathBlock(MathExpr)
  Table(Int, Array[Array[Inline]])
  Shape(ShapeKind, ShapeStyle)       // 矢量形状 (矩形、圆形、线条)
  Grid(Array[Length], Array[Block])  // 多列网格布局
  FootnoteBlock(Int, Array[Inline])  // 脚注块
  Figure(Block, Array[Inline]?)      // 带图题的插图
  AlignBlock(Alignment, Block)       // 空间对齐块
  HorizontalRule
  PageBreak
}

// 扩展数学公式表达式 (含矩阵、向量、重音、极限)
pub enum MathExpr {
  Sym(String)
  Frac(MathExpr, MathExpr)
  Sqrt(MathExpr)
  SubSup(MathExpr, MathExpr?, MathExpr?)
  Matrix(Int, Int, Array[MathExpr])  // rows, cols, elements
  Vector(Array[MathExpr])            // elements
  Accent(String, MathExpr)           // "hat", "tilde", "bar", "dot"
  Limits(String, MathExpr?, MathExpr?) // "sum", "int" 等
  Group(Array[MathExpr])
  Op(String)
}
```

### 3.2 布局几何盒模型 (`layout/box.mbt`)

```moonbit
pub struct Rect {
  x : Double
  y : Double
  w : Double
  h : Double
}

pub enum BoxKind {
  Text(String, Double, String, String)  // text, font_size, color_hex, weight
  RectFill(Double, Double, String, Double) // w, h, fill_hex, radius
  RectStroke(Double, Double, String, Double, Double) // w, h, stroke_hex, stroke_width, radius
  Line(Double, Double, Double, Double, String, Double) // x1, y1, x2, y2, color_hex, width
  Circle(Double, String, String, Double) // radius, fill_hex, stroke_hex, stroke_width
  FootnoteMarker(Int, Double, String)
  FootnoteItem(Int, String, Double, String)
  MathSymbol(String, Double, String)
  FracBar(Double, Double, Double, String)
  Radical(Double, Double, Double, Double, String)
}
```

---

## 4. 纯 MoonBit PDF 1.4 二进制生成器架构 (`render/pdf.mbt`)

`render/pdf.mbt` 彻底避免了 C-FFI 外部动态链接库依赖，直接在 MoonBit 内存中构建标准 Adobe PDF 1.4 二进制格式：

1. **Header**：标准 `%PDF-1.4` 及二进制魔数标记 `%\xe2\xe3\xcf\xd3\n`；
2. **Catalog & Pages Tree**：通过间接对象引用建立文档页面树拓扑；
3. **Font Resources**：嵌入 4 类标准 PostScript / Type1 字体字典：
   - `/F1` (`/Helvetica`)
   - `/F2` (`/Helvetica-Bold`)
   - `/F3` (`/Times-Italic`)
   - `/F4` (`/Courier`)
4. **Drawing Stream Operators**：将页面盒模型精确编译为 PDF 图形绘制流（`BT`/`ET` 文本操作、`rg`/`RG` 颜色空间、`re`/`f` 填充矩形、`m`/`l`/`S` 矢量划线、`d` 虚线与分式横线）；
5. **Cross-Reference Table (`xref`)**：动态追踪全部间接对象的字节起始偏移并精确填充 10 位 ASCII 定宽偏移量；
6. **Trailer & %%EOF**：输出文档 Root 字典与 startxref 偏移标记。

---

## 5. 跨平台支持

`moon-typst` 坚持 100% 纯 MoonBit 原生代码实现：
- 编译至 `wasm-gc`、`wasm`（可无缝集成至 Web 编辑器、浏览器插件及云原生边缘服务）；
- 编译至 `js`（适用于 Node.js / Bun 服务端轻量渲染）；
- 编译至 `native`（跨平台极速命令行编译工具 `typst-render`，支持 Linux, macOS, Windows）。

