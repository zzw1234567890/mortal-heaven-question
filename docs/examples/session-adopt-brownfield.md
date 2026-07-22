
# 示例会话：/adopt — Brownfield 项目接入

**上下文：** 开发者在发现本代理系统之前已经构建游戏 3 个月。他们有代码、一些设计文档和粗略笔记——但没有任何内容符合技能所需的正确格式。

**起始状态：**
- `src/gameplay/` — 约 4000 行 Godot 4.6 GDScript
- `design/` — 3 个含粗略设计笔记的 markdown 文件（非 GDD 模板格式）
- 没有 `design/gdd/` 目录
- 没有 `docs/architecture/` 目录
- 没有 `production/` 目录
- 没有 `design/gdd/systems-index.md`
- CLAUDE.md 存在（引擎已配置：Godot 4.6）

**会话时长：** 约 30 分钟
**轮次：** 8
**结果：** 接入计划已写入，最紧急的缺口（缺失的系统索引）立即修复

---

## 第 1 轮：用户调用 /adopt

**User:**
> /adopt

## 第 2 轮：代理检测项目状态

**Agent (technical-director, via /adopt, context: fork):**
> 运行 brownfield 审计...
>
> **阶段 1：项目状态检测**
>
> | 工件类别 | 找到 | 备注 |
> |------------------|-------|-------|
> | 引擎配置 | ✅ | CLAUDE.md 中为 Godot 4.6 |
> | 源代码 | ✅ | `src/gameplay/` 约 4000 行 |
> | 设计文档 | ⚠️ | `design/` 中 3 个文件，非 GDD 格式 |
> | 架构文档 | ❌ | `docs/architecture/` 缺失 |
> | 系统索引 | ❌ | `design/gdd/systems-index.md` 缺失 |
> | 生产跟踪 | ❌ | `production/` 目录缺失 |
> | Sprint/story 文件 | ❌ | 无 |
>
> **阶段 2：格式审计（现有文件）**
>
> 检查 3 个设计文件的内部结构...
>
> *`design/combat-notes.md`:*
> - 含非正式笔记，无 GDD 模板章节
> - 包含：一些规则描述、一个伤害公式、粗略平衡数值
> - GDD 模板缺失：Overview、Player Fantasy、Edge Cases、Dependencies、Tuning Knobs、Acceptance Criteria（8 节中的 6 节）
>
> *`design/crafting-ideas.md`:*
> - 头脑风暴式笔记，无结构
> - 无公式、无验收标准
> - 代表早期概念思考——可作为 GDD 的输入，但本身还不是 GDD
>
> *`design/inventory.md`:*
> - 最接近 GDD——含 Overview 和 Rules 章节
> - 缺失：Player Fantasy、Formulas、Edge Cases、Tuning Knobs、Acceptance Criteria（8 节中的 5 节）
>
> **阶段 3：缺口分类**
>
> | 缺口 | 严重性 | 原因 |
> |-----|----------|--------|
> | 无系统索引 | BLOCKING | `/design-system`、`/create-stories`、`/gate-check` 都需要它 |
> | GDD 文件非模板格式 | HIGH | 技能无法从格式错误的 GDD 引用 TR-ID |
> | 无架构文档 | HIGH | 无法运行 `/architecture-review` 或 `/create-control-manifest` |
> | 无生产跟踪 | MEDIUM | Sprint 和 story 技能无法工作，但生产阶段前不需要 |
> | `design/crafting-ideas.md` — pre-GDD 内容 | LOW | 作为输入有用；在阻塞任何东西之前需要完整 GDD 编写 |

## 第 3 轮：代理呈现迁移计划

**Agent:**
> **阶段 4：迁移计划**
>
> 7 个有序步骤将你的项目带入完全对齐。绝不覆盖你现有的内容——每一步只填补缺口。
>
> | # | 步骤 | 技能 | 优先级 | 备注 |
> |---|------|-------|----------|-------|
> | 1 | 创建 `design/gdd/systems-index.md` | `/map-systems` 或 `/adopt` 内联 | BLOCKING | 解锁所有下游技能 |
> | 2 | 改造 `design/inventory.md` → GDD 格式 | `/design-system retrofit design/inventory.md` | HIGH | 添加 5 个缺失章节，保留你现有内容 |
> | 3 | 改造 `design/combat-notes.md` → GDD 格式 | `/design-system retrofit design/combat-notes.md` | HIGH | 添加 6 个缺失章节 |
> | 4 | 将 `design/crafting-ideas.md` 转为完整 GDD | `/design-system crafting`（全新编写，以 ideas 为输入） | MEDIUM | 不是 retrofit——太不正式无法 retrofit |
> | 5 | 从现有代码创建架构 ADR | `/reverse-document` + `/architecture-decision` | HIGH | 捕捉代码中已做出的决策 |
> | 6 | 创建主架构文档 | `/create-architecture` | HIGH | 在 ADR 之后 |
> | 7 | 设置生产跟踪 | `/sprint-plan new` | MEDIUM | 在架构阶段之后 |
>
> **重要：** 步骤 1 必须在任何其他步骤之前发生。其他都可以并行或根据你的优先级重排。
>
> 我可以把这个计划写到 `docs/adoption-plan-2026-03-12.md` 吗？

**User:**
> 是的，写吧。

**代理写入接入计划。**

## 第 4 轮：代理提议修复最紧急的缺口

**Agent:**
> BLOCKING 缺口是缺失的 `design/gdd/systems-index.md`。
>
> 我现在可以通过读取你现有的代码和设计文档来推断你已构建的系统，从而创建一个。这比从头运行 `/map-systems` 更快——我会基于已存在的内容填充它，然后你确认或调整。
>
> 你想让我现在做吗？

**User:**
> 是的，做吧。

## 第 5 轮：代理读取代码库并起草系统索引

**Agent:**
> 读取 `src/gameplay/` 以推断系统...
>
> 在代码中找到这些系统边界：
>
> - `src/gameplay/combat/` — 伤害计算、命中检测、状态效果
> - `src/gameplay/inventory/` — 物品管理、重量、堆叠
> - `src/gameplay/crafting/` — 配方查找、结果生成（引用 inventory）
> - `src/gameplay/movement/` — CharacterBody2D、地形修改器（被 combat 引用用于定位）
> - `src/gameplay/ui/` — HUD、inventory 界面、对话框
> - `src/gameplay/world/` — tile map、地形类型、区块加载
>
> **系统索引草稿：**
>
> | 系统 | 类别 | 优先级 | 依赖 | GDD 状态 |
> |--------|----------|----------|--------------|------------|
> | Movement | Foundation | MVP | 无 | ❌ 缺失 |
> | World/Terrain | Foundation | MVP | Movement | ❌ 缺失 |
> | Combat | Core | MVP | Movement | ⚠️ 需 retrofit |
> | Inventory | Core | MVP | 无 | ⚠️ 需 retrofit |
> | Crafting | Feature | MVP | Inventory | ❌ 仅 pre-GDD |
> | UI / HUD | Presentation | MVP | Combat, Inventory, Movement | ❌ 缺失 |
>
> 这看起来对吗？我漏掉或误分类了什么吗？

**User:**
> 看起来对。加一个 Stamina 系统——它在 combat/ 里但应该是独立系统。

**Agent:**
> 已将 Stamina 添加为 Core / MVP 系统：
>
> | Stamina | Core | MVP | Movement, Combat | ❌ 缺失 |
>
> 更新依赖：Movement 依赖 Stamina（移动消耗它）。
>
> 我可以写到 `design/gdd/systems-index.md` 吗？

## 第 6 轮：用户批准

**User:**
> 是的

**代理写入 `design/gdd/systems-index.md`。**

## 第 7 轮：代理展示现已解锁的内容

**Agent:**
> `design/gdd/systems-index.md` 已创建。
>
> **BLOCKING 缺口已解决。** 以下技能现在可以运行：
>
> - ✅ `/design-system [name]` — 为任何系统引导 GDD 编写
> - ✅ `/design-system retrofit [path]` — 填补现有文档中缺失的章节
> - ✅ `/gate-check` — 现在有系统索引可验证
> - ✅ `/help` — 现在能显示正确的阶段工作流
>
> **推荐的后续步骤（来自接入计划）：**
>
> 1. 运行 `/design-system retrofit design/inventory.md` — 你最完整的现有文档，最容易的胜利
> 2. 运行 `/design-system retrofit design/combat-notes.md`
> 3. 运行 `/design-system crafting` — 用你的 ideas 文件作为输入编写 crafting GDD
>
> 这 3 步之后，你将有 7 个系统中的 5 个具备完整 GDD。然后运行 `/review-all-gdds` 在架构工作之前捕捉跨系统一致性问题。

## 第 8 轮：用户确认计划

**User:**
> 完美。我将从 inventory retrofit 开始。

**Agent:**
> 运行：
> ```
> /design-system retrofit design/inventory.md
> ```
>
> 该技能会检测你现有的 Overview 和 Rules 章节，向你展示 8 个章节中哪些缺失，并仅针对缺口运行章节循环。你现有的内容不会被触碰。

---

## 本示例展示的内容

- **FORMAT 审计，而非存在性审计**：`/adopt` 不只检查文件是否存在——它检查内部结构是否匹配技能所期望的。一个名为 `gdd.md` 但无模板章节的文件会被标记为缺口。
- **迁移，而非替换**：现有内容绝不被覆盖。计划只填补缺口。
- **BLOCKING 缺口优先浮现**：缺失的系统索引被识别为 BLOCKING，因为它阻止了最多技能运作。
- **紧急缺口的内联创建**：代理不只是报告缺口，而是提议在同一会话中立即修复。
- **从代码推断**：系统索引从代码库结构引导生成，而非从头编写——brownfield 代码已包含答案。
- **Retrofit vs. 全新编写**：`/design-system retrofit` 处理现有但不完整的文档；完整 `/design-system` 处理全新文档。接入计划区分每个文件适用哪种。
- **Context: fork**：`/adopt` 在 forked 上下文中运行，以避免用整个代码库的大文件读取污染主会话。
