# Development Log: moon-typst

本文档记录 `moon-typst` 项目在 **2026 9月 MoonBit 黑客松** 期间的开发历程、关键技术攻关与阶段性成果。

---

## 阶段规划与里程碑完成情况

- [x] **Milestone 1: 项目立项与工程初始化**
  - 完成选题生态查重（GitHub & mooncakes.io 双重核验，排除 2493 个已有模块，确立 Typst 排版渲染方向）。
  - 配置 `moon.mod` 模块与 Apache-2.0 许可证。
  - 编写项目申报书 (`proposal.md`)、系统架构说明 (`architecture.md`)。
- [x] **Milestone 2: 核心抽象与 AST 定义 (`core`)**
  - 定义文档容器（`Doc`）、块级元素（`Block`）、行内标记（`Inline`）与数学公式表达式树（`MathExpr`）。
  - 实现排版样式上下文（`StyleContext`）及尺寸几何常量。
  - 编写 AST 构造与结构完整性单元测试（`ast_test.mbt`）。
- [x] **Milestone 3: 词法分析与递归下降语法解析 (`parser`)**
  - 实现零回溯状态机 Tokenizer，支持标题（`=`）、样式（`*`、`_`）、列表（`-`、`+`）、代码块、数学块与表格（`|`）。
  - 攻克 UTF-8 BOM（`\uFEFF`）与 CRLF 换行兼容问题。
  - 实现多操作符数学公式解析器（支持加减乘除、分式 `frac`、根式 `sqrt`、括号嵌套）。
  - 编写覆盖异常输入、未闭合标记、边界情况的高覆盖率测试套件（`lexer_test.mbt`、`parser_test.mbt`）。
- [x] **Milestone 4: 流式盒模型几何排版引擎 (`layout`)**
  - 建立页面边界、文字宽度估算与自动折行算法（Word Wrap）。
  - 布局计算器输出统一几何盒树（`LayoutBox`：文本盒、矩形盒、线条盒、表格单元盒、公式盒）。
  - 编写多段落几何间距递增与盒模型累积测试（`layout_test.mbt`）。
- [x] **Milestone 5: 多后端渲染器 (`render`)**
  - 实现标准矢量 SVG 渲染输出，精准生成 `<rect>`, `<text>`, `<line>`, `<g>` 标签（`svg.mbt`）。
  - 实现语义化响应式 HTML5 渲染输出，内嵌现代科技风排版 CSS（`html.mbt`）。
  - 编写 SVG 根标签闭合与 HTML 语义化标签渲染断言测试（`render_test.mbt`）。
- [x] **Milestone 6: 命令行工具与可复现用例套件 (`cmd` & `examples`)**
  - 基于 MoonBit 现代语法实现原生可执行 CLI 工具 `typst-render`（`cmd/main/main.mbt`）。
  - 支持 `-o` 输出路径自定义、`--html` / `--svg` 模式切换、`-h` 帮助提示与详细编译日志输出。
  - 构建 3 套涵盖学术、求职、工业报告的高保真真实用例套件（`paper.typ`, `resume.typ`, `report.typ`）。
  - 自动化批量预编译导出高保真 `.svg` 与 `.html` 交付物。
- [x] **Milestone 7: CI 流水线与质量验收**
  - 配置 GitHub Actions 多操作系统矩阵（`ubuntu-latest`, `macos-latest`, `windows-latest`）。
  - 集成 `moon version`, `moon fmt --check`, `moon check --deny-warn`, `moon test --deny-warn`。
  - 覆盖 `wasm-gc`, `js`, `native` 多目标平台全量构建检查与端到端渲染回归测试。
- [x] **Milestone 8: 发布准备与最终文档**
  - 完善中英文双语高标准 `README.md`，配齐架构图、语法对照表、基准测试数据。
  - 更新项目申报书与技术架构设计文档。

---

## 规范递进提交历史记录 (Git Commits)

本项目严格遵循原子化提交与 Conventional Commits 规范，所有提交均由认证参赛账号 `Lxxbv` 独立完成：

1. `df05574` - `chore: initialize moon-typst repository with moon.mod, license, and gitignore`
2. `abf8e9a` - `docs: add competition proposal, architecture design, and development roadmap`
3. `2be05d6` - `feat(core): define document AST, inline/block models, and styling context`
4. `ccfe214` - `feat(parser): implement Typst markup tokenizer and lexical scanner`
5. `1c2b2b1` - `feat(parser): implement recursive descent parser for Typst document AST`
6. `d554e01` - `test(parser): add comprehensive test suites for lexer and parser edge cases`
7. `4bbe7c5` - `feat(layout): implement flow layout engine and geometrical box calculation`
8. `5a96467` - `feat(render): implement high-fidelity SVG vector graphics generator`
9. `9674697` - `feat(render): implement semantic HTML5 document renderer`
10. `904cacf` - `feat(cmd): build typst-render command line interface with CLI arguments`
11. `c013548` - `feat(examples): provide realistic demo suite (paper, resume, technical report)`
12. `526c1ad` - `ci: add GitHub Actions workflow and format codebase with moon fmt`
13. `docs: finalize bilingual README with usage guide, benchmarks, and API reference`

---

## 关键技术攻关与经验总结

1. **零 C-FFI 的可移植性收益**：
   通过纯 MoonBit 算法实现字宽预估与盒模型拆解，使 `moon-typst` 彻底摆脱了传统排版工具对动态字体链接库（如 FreeType/HarfBuzz）的强依赖，编译后的 Wasm 体积微小且完全确定性。
2. **纯函数式 AST 与模式匹配**：
   在 MoonBit 中使用不可变代数数据类型（ADT）结合编译器穷尽性检查（Exhaustiveness Checking），确保了在处理各种极端嵌套标记（如粗斜体嵌套、代码块中未转义字符、不规则表格行）时绝不会发生运行时越界或崩溃。
3. **跨平台与现代语法适配**：
   统一遵循 MoonBit 2026 现代编译器语法规则（`derive(Debug, Eq)`, `assert_eq`, `StringBuilder()`, `s[i].to_int().unsafe_to_char()`），杜绝了编译器废弃警告，在 `ubuntu`、`macos` 与 `windows` 下表现完全一致。
