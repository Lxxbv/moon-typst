# Development Log: moon-typst

本文档记录 `moon-typst` 项目在 **2026 9月 MoonBit 黑客松** 期间的开发历程、关键技术攻关与阶段性成果。

---

## 阶段规划与里程碑

- [x] **Milestone 1: 项目立项与工程初始化**
  - 完成选题生态查重（GitHub & mooncakes.io 双重核验）。
  - 配置 `moon.mod` 模块与 Apache-2.0 许可证。
  - 编写项目申报书 (`proposal.md`)、系统架构说明 (`architecture.md`)。
- [ ] **Milestone 2: 核心抽象与 AST 定义 (`core`)**
  - 定义文档容器、块级元素、行内标记与数学公式表达式树。
  - 编写 AST 打印与构建测试。
- [ ] **Milestone 3: 词法分析与递归下降语法解析 (`parser`)**
  - 实现状态机 Tokenizer，支持标题、样式、列表、代码块、数学块。
  - 实现递归下降语法解析器，将 Typst 文本构建为 `Doc` AST。
  - 覆盖边界与异常输入的测试套件。
- [ ] **Milestone 4: 流式盒模型几何排版引擎 (`layout`)**
  - 建立页面边界、文本测量与行折叠算法。
  - 布局计算器输出统一几何盒树（Layout Box Tree）。
- [ ] **Milestone 5: 多后端渲染器 (`render`)**
  - 实现标准矢量 SVG 渲染输出。
  - 实现语义化响应式 HTML5 渲染输出。
- [ ] **Milestone 6: 命令行工具与可复现用例套件 (`cmd` & `examples`)**
  - 编译可执行 CLI 工具 `typst-render`。
  - 编写学术论文、简历、技术报告等 3 套官方示例。
- [ ] **Milestone 7: CI 流水线与质量验收**
  - 配置 GitHub Actions 多操作系统矩阵自动化验证。
  - 格式检查、静态检查、全量单元测试绿灯。
- [ ] **Milestone 8: 发布与成果归档**
  - 完善中英文双语 README。
  - 准备 mooncakes.io 发版与最终验收材料。

---

## 提交记录与技术要点（持续更新）

- **Commit 1 (`df05574`)**: `chore: initialize moon-typst repository with moon.mod, license, and gitignore`
  - 初始化 Git 仓库，设置 `Lxxbv` 提交者，创建 `moon.mod`、Apache-2.0 协议与 `.gitignore`。
- **Commit 2**: `docs: add competition proposal, architecture design, and development roadmap`
  - 编写官方格式申报书、技术架构说明及开发日志。
