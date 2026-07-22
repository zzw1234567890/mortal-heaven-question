
# 示例会话：/gate-check 阶段过渡 — 系统设计 → 技术设置

**上下文：** 独立开发者，第 5 周末。系统设计阶段感觉已完成——6 个 MVP GDD 已编写，交叉评审完成，引擎已设置。用户希望正式推进到技术设置 (Technical Setup)。

**起始状态：**
- `production/stage.txt` — 当前为 `systems-design`
- `design/gdd/systems-index.md` — 列出 6 个 MVP 系统，全部标记 `Status: GDD Complete`
- `design/gdd/` — 存在 6 个 GDD 文件
- `design/gdd/gdd-cross-review-2026-03-10.md` — 交叉评审报告，判定：CONCERNS（1 条低优先级备注）
- 引擎已配置（Godot 4.6，`/setup-engine` 完成）

**会话时长：** 约 20 分钟
**轮次：** 7
**结果：** 闸门通过，`stage.txt` 更新为 `technical-setup`，清晰的后续清单

---

## 第 1 轮：用户发起闸门检查

**User:**
> /gate-check

## 第 2 轮：代理检测当前阶段并运行检查

**Agent (via /gate-check):**
> 读取 `production/stage.txt` — 当前阶段：**systems-design**
>
> 运行闸门：**Systems Design → Technical Setup**
>
> ---
> **必需工件清单：**
>
> | 工件 | 要求 | 状态 |
> |----------|-------------|--------|
> | `design/gdd/systems-index.md` | 存在，所有 MVP 系统列出 | ✅ |
> | 逐系统 GDD | 所有 MVP 系统都有 GDD | ✅ (6/6) |
> | 每个 GDD 的 `/design-review` | 每个 GDD 已评审 | ✅ (找到 6/6 评审备注) |
> | 跨 GDD 评审报告 | `design/gdd/gdd-cross-review-*.md` 存在 | ✅ |
> | 交叉评审判定 | PASS 或 CONCERNS（非 FAIL） | ✅ CONCERNS |
> | 引擎已配置 | `production/stage.txt` 或 CLAUDE.md 引擎条目 | ✅ Godot 4.6 |
>
> ---
> **内容扫描：**
>
> 检查 GDD 完整性（每个 8 个必需章节）...
>
> | GDD | 缺失章节 |
> |-----|-----------------|
> | movement-system.md | 无 ✅ |
> | stamina-system.md | 无 ✅ |
> | combat-system.md | 无 ✅ |
> | inventory-system.md | 无 ✅ |
> | crafting-system.md | 无 ✅ |
> | exploration-system.md | 无 ✅ |
>
> ---
> **交叉评审关注点（来自 `gdd-cross-review-2026-03-10.md`）：**
>
> 1. ⚠️ LOW — Crafting 和 inventory 都独立定义了"物品堆叠大小"且默认值不同（crafting：99，inventory：64）。一个系统应是权威；另一个应引用它。非阻塞——可在 ADR 中解决。
>
> ---
> **判定：PASS**
>
> 所有必需工件存在。交叉评审关注点为 LOW 严重性，可在技术设置阶段通过 ADR 解决。这是此阶段的正常发现。
>
> **我可以将 `production/stage.txt` 推进到 `technical-setup` 吗？**

## 第 3 轮：用户确认

**User:**
> 是的，推进吧。

## 第 4 轮：代理更新阶段并呈现后续步骤

**Agent:**
> 已更新 `production/stage.txt` → `technical-setup`
>
> ---
> **你现在处于：Technical Setup**
>
> 此阶段在生产编码开始前建立技术基础。你的目标是完整、已批准的架构，以便 Pre-Production 中编写的每个 story 都有清晰、无歧义的技术指引。
>
> **本阶段必需步骤（按顺序）：**
>
> 1. **`/create-architecture`** — 编写主架构文档。涵盖系统分解、数据流、分层边界和模块职责。
>
> 2. **`/architecture-decision`（每个重要技术选择一个）** — 至少：
>    - 渲染方法（2D 相机、视口等）
>    - 存档/加载策略
>    - 音频总线架构
>    - 来自交叉评审的"物品堆叠大小权威"问题（crafting vs. inventory）
>
> 3. **`/architecture-review`** — 验证所有 ADR 的完整性、依赖排序和 GDD 可追溯性。产出 TR-registry。
>
> 4. **`/create-control-manifest`** — 将 Accepted ADR 转为扁平的程序员规则表。这是实现代理在编码时将查阅的内容。
>
> 5. **`/gate-check`** — Technical Setup → Pre-Production 闸门。要求：架构文档、所有 ADR 为 Accepted、control manifest、依赖排序已解决。
>
> **可选但推荐：**
> - `/tech-debt` 扫描，如果你有计划保留的原型代码
> - `/setup-engine` 重跑，如果你尚未获取 Godot 4.6 API 快照
>
> **提示：** 从 `/architecture-decision` 处理堆叠大小冲突开始。这是一个快速胜利，能在它造成两个 ADR 的歧义之前关闭一个未决问题。

## 第 5 轮：用户询问交叉评审关注点

**User:**
> 堆叠大小冲突的 ADR 我实际该写什么？

## 第 6 轮：代理提供建议

**Agent:**
> ADR 决策是：**哪个系统拥有规范的 `max_stack_size` 值？**
>
> 两个选项供考虑：
>
> **选项 A：Inventory 拥有它**
> - `ItemData` 资源（由 inventory 拥有）有 `max_stack_size: int = 64`
> - Crafting 系统从 `ItemData` 读取，绝不设置自己的值
> - 优点：inventory 是所有物品属性的真相源
> - 缺点：crafting 团队需要知道去看 inventory 数据
>
> **选项 B：物品数据资源拥有它（共享资源）**
> - `ItemData.max_stack_size` 是两个系统的权威
> - Crafting 和 inventory 都从 `ItemData` 导入
> - 优点：单一来源，crafting 和 inventory 模块间无耦合
> - 缺点：共享数据层又多一样东西
>
> 多数工作室在有 >2 个系统触碰物品数据时选择 B（共享资源）。但对独立项目两者都有效。
>
> 运行 `/architecture-decision`，它会引导你完成 ADR 格式，包括将此 ADR 链回两个 GDD 的 Dependencies 章节。

## 第 7 轮：用户收尾

**User:**
> 明白了。我将从 /architecture-decision 开始处理这个。

**Agent:**
> 好的起点。ADR 将记录决策、理由以及它解决的 GDD 需求——所以当你在数月后写代码时，理据得以保留。
>
> 你的阶段闸门已记录。在 Technical Setup 期间随时运行 `/help` 查看你对照必需清单的当前进度。

---

## 本示例展示的内容

- **闸门检查是自动化的，非手动的**：代理读取工件并检查它们——用户不需填表
- **CONCERNS ≠ FAIL**：交叉评审关注点为 LOW 严重性并通过闸门。FAIL 才需要在推进前解决。
- **stage.txt 是权威**：状态行、`/help` 和所有技能都从 `production/stage.txt` 读取——在此更新它改变了每个后续技能所见
- **后续步骤是阶段特定的**：代理不给泛泛的"祝你好运"——它给出 Technical Setup 特定的有序清单
- **闸门检查浮现延续工作**：堆叠大小冲突是交叉评审备注；闸门检查确保它成为具体 ADR 而非丢失
- **每次闸门仅推进一次**：用户明确确认推进。闸门不自动推进；需要人类确认。
