
# 设计目录


在本文档目录中创作或编辑文件时，请遵循以下标准。

## GDD 文件 (`design/gdd/`)

每个 GDD 必须按此顺序包含全部 **8 个必填章节**：
1. 概览 (Overview) —— 一段式摘要
2. 玩家幻想 (Player Fantasy) —— 预期的感受与体验
3. 详细规则 (Detailed Rules) —— 明确无歧义的机制
4. 公式 (Formulas) —— 所有数学公式及变量定义
5. 边缘情况 (Edge Cases) —— 处理非常规情境
6. 依赖 (Dependencies) —— 列出相关其他系统
7. 调参旋钮 (Tuning Knobs) —— 标识可配置的数值
8. 验收标准 (Acceptance Criteria) —— 可测试的成功条件

**文件命名：** `[system-slug].md`（例如 `movement-system.md`、`combat-system.md`）

**系统索引：** `design/gdd/systems-index.md` —— 新增 GDD 时同步更新。

**设计顺序：** 基础 (Foundation) → 核心 (Core) → 功能 (Feature) → 表现 (Presentation) → 打磨 (Polish)

**验证：** 创作任何 GDD 后运行 `/design-review [path]`。
完成一组相关 GDD 后运行 `/review-all-gdds`。

## 快速规格 (`design/quick-specs/`)

用于调整改动、小型机制或平衡性微调的轻量规格。
使用 `/quick-design` 创作。

## UX 规格 (`design/ux/`)

- 每屏规格：`design/ux/[screen-name].md`
- HUD 设计：`design/ux/hud.md`
- 交互模式库：`design/ux/interaction-patterns.md`
- 无障碍需求：`design/ux/accessibility-requirements.md`

使用 `/ux-design` 创作。在交付给 `/team-ui` 之前用 `/ux-review` 验证。
