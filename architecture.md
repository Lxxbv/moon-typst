# Architecture Specification: moon-typst

`moon-typst` 是一个纯 MoonBit 实现的轻量级 Typst 标记语言解析、盒模型排版与多后端渲染引擎。本文档描述其系统架构、分层设计、核心数据流与接口规范。

---

## 1. 整体架构流水线

`moon-typst` 采用经典的多阶段编译器前端与图形排版管线：

```text
+-------------------+
|  Typst Text .typ  |
+-------------------+
          |
          v
+-------------------+  (parser/lexer.mbt)
|   Token Stream    |  识别 Heading, InlineFormat, Math, Code, List
+-------------------+
          |
          v
+-------------------+  (parser/parser.mbt)
|   Document AST    |  结构化不可变语法树 (Doc, Block, Inline, MathExpr)
+-------------------+
          |
          v
+-------------------+  (layout/engine.mbt)
|  Layout Box Tree  |  盒模型几何测量、折行排布 (x, y, width, height)
+-------------------+
          |
    +-----+-----+
    |           |
    v           v
+-------+   +--------+
|  SVG  |   |  HTML  |  (render/svg.mbt, render/html.mbt)
+-------+   +--------+
```

---

## 2. 模块划分与包依赖

项目结构遵循 MoonBit 现代模块规范：

```text
moon-typst/
├── moon.mod               # 模块配置 (name = "Lxxbv/moon_typst")
├── core/                  # 核心数据模型与抽象
│   ├── moon.pkg
│   ├── ast.mbt            # Doc, Block, Inline, MathExpr, Alignment, Style
│   └── ast_test.mbt       # 核心模型测试
├── parser/                # 词法扫描器与语法解析器
│   ├── moon.pkg
│   ├── token.mbt          # Token 枚举与位置定义
│   ├── lexer.mbt          # 纯 MoonBit 词法状态机
│   ├── parser.mbt         # 递归下降语法解析器
│   └── parser_test.mbt    # 语法测试套件
├── layout/                # 排版与几何盒模型计算
│   ├── moon.pkg
│   ├── box.mbt            # Box, Rect, TextMetrics, LayoutNode
│   ├── engine.mbt         # 流式折行排版算法
│   └── layout_test.mbt    # 排版计算测试
├── render/                # 渲染后端
│   ├── moon.pkg
│   ├── svg.mbt            # SVG 矢量输出器
│   ├── html.mbt           # HTML5 结构化输出器
│   └── render_test.mbt    # 渲染器单元测试
├── cmd/                   # 命令行应用
│   └── main/
│       ├── moon.pkg
│       └── main.mbt       # CLI 入口与参数解析
└── examples/              # 可运行测试样例 (.typ)
    ├── paper.typ
    ├── resume.typ
    └── report.typ
```

### 依赖关系图：
- `cmd/main` -> `render`, `layout`, `parser`, `core`
- `render` -> `layout`, `core`
- `layout` -> `core`
- `parser` -> `core`
- `core` -> 无任何项目内依赖（仅依赖 MoonBit 标准库）

---

## 3. 核心数据结构设计

### 3.1 Document AST (`core/ast.mbt`)

```moonbit
// 文档顶级容器
pub struct Doc {
  blocks : Array[Block]
}

// 块级元素
pub enum Block {
  Heading(Int, Array[Inline])        // 层级 (1~6), 行内内容
  Paragraph(Array[Inline])           // 段落
  List(Bool, Array[Array[Inline]])   // ordered, list_items
  CodeBlock(String, String)          // lang, code_content
  MathBlock(MathExpr)                // 块级数学公式
  Table(Int, Array[Array[Inline]])   // 列数, 单元格
  HorizontalRule                     // 水平分隔线
}

// 行内元素
pub enum Inline {
  Text(String)
  Bold(Array[Inline])
  Italic(Array[Inline])
  Code(String)
  InlineMath(MathExpr)
  Link(String, String)               // url, text
  LineBreak
}

// 数学公式表达式
pub enum MathExpr {
  Sym(String)                        // 符号/变量/数字
  Frac(MathExpr, MathExpr)           // 分式 \frac{a}{b}
  SubSup(MathExpr, MathExpr?, MathExpr?) // 底数, 下标, 上标
  Group(Array[MathExpr])             // 括号复合表达式
  Op(String)                         // 算符 (+, -, *, =, etc.)
}
```

### 3.2 布局几何盒模型 (`layout/box.mbt`)

```moonbit
pub struct Rect {
  x : Double
  y : Double
  width : Double
  height : Double
}

pub struct LayoutBox {
  rect : Rect
  content : BoxContent
}

pub enum BoxContent {
  TextBox(String, Double, String)    // text, font_size, color
  RectBox(Double, Double, String)    // width, height, fill/stroke
  LineBox(Double, Double, Double, Double, String) // x1, y1, x2, y2, stroke
  Container(Array[LayoutBox])
}
```

---

## 4. 排版算法关键逻辑

1. **页面与边距约束**：
   - 默认采用 A4 尺寸比例（宽 800px，边距 50px，内容宽度 700px）。
2. **字符测量与折行（Word Wrap）**：
   - 基于字体大小和比例因子计算文本块宽度；
   - 遇到超出内容宽度时自动折行并创建下一行子盒；
   - 段落之间自动计算留白（`margin_bottom`）。
3. **公式盒模型排布**：
   - 分式 `Frac(num, den)` 自动计算分子与分母中心对齐、分界线长度与上下垂直间距；
   - 上下标自动缩小比例（0.7x）并调整基线偏移。

---

## 5. 跨平台支持

`moon-typst` 保持 100% 纯 MoonBit 原生代码实现：
- 完美编译至 `wasm-gc`、`wasm`（适用于浏览器与前端生态）；
- 编译至 `js`（Node.js / Bun 运行时）；
- 编译至 `native`（跨平台高性能二进制命令行工具）。
