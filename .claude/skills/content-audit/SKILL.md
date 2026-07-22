---
name: content-audit
description: "审计 GDD 中指定的内容数量与已实现的内容的对比。识别已规划与已构建之间的差距。"
argument-hint: "[system-name | --summary | (no arg = full audit)]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write

agent: producer
---


当此技能被调用时：

解析参数：
- 无参数 → 对所有系统进行全面审计
- `[system-name]` → 仅审计该单个系统
- `--summary` → 仅显示摘要表格，不写入文件

---

## 第一阶段 — 上下文收集

1. **读取 `design/gdd/systems-index.md`** 获取系统完整列表、其分类及 MVP/优先级层级。

2. **L0 预扫描**：在完整读取任何 GDD 之前，在所有 GDD 文件中 grep 搜索 `## Summary` 章节及常见内容计数关键词：
   ```
   Grep pattern="(## Summary|N enemies|N levels|N items|N abilities|enemy types|item types)" glob="design/gdd/*.md" output_mode="files_with_matches"
   ```
   对于单系统审计：跳过此步骤，直接进入完整读取。
   对于全面审计：仅完整读取那些匹配了内容计数关键词的 GDD。没有内容计数描述（纯机制型 GDD）的 GDD 被标记为"无可审计内容计数"，无需完整读取。

3. **完整读取范围内的 GDD 文件**（如果给定了系统名称，则读取单个系统 GDD）。

4. **为每个 GDD，提取明确的内容计数或列表。**查找如下模式：
   - "N 个敌人" / "敌人类型：" / 已命名的敌人列表
   - "N 个关卡" / "N 个区域" / "N 张地图" / "N 个阶段"
   - "N 个物品" / "N 种武器" / "N 件装备"
   - "N 种能力" / "N 种技能" / "N 种法术"
   - "N 个对话场景" / "N 段对话" / "N 段过场动画"
   - "N 个任务" / "N 个使命" / "N 个目标"
   - 任何明确的枚举列表（已命名内容项目的符号列表）

4. **从提取的数据构建内容清单表：**

   | 系统 | 内容类型 | 指定数量/列表 | 来源 GDD |
   |--------|-------------|---------------------|------------|

   注意：如果 GDD 定性地描述了内容但没有给出数量，记录"未指定（Unspecified）"并标记——未指定的数量是值得注意的设计缺口。

---

## 第二阶段 — 实现扫描

对于第一阶段中发现的每种内容类型，扫描相关目录以统计已实现的内容。使用 Glob 和 Grep 定位文件。

**关卡 / 区域 / 地图：**
- Glob `assets/**/*.tscn`、`assets/**/*.unity`、`assets/**/*.umap`
- Glob `src/**/*.tscn`、`src/**/*.unity`
- 查找 `levels/`、`areas/`、`maps/`、`worlds/`、`stages/` 等子目录中的场景文件
- 统计似乎是关卡/场景定义的文件数量（不包括 UI 场景）

**敌人 / 角色 / NPC：**
- Glob `assets/data/**/enemies/**`、`assets/data/**/characters/**`
- Glob `src/**/enemies/**`、`src/**/characters/**`
- 查找定义实体属性的 `.json`、`.tres`、`.asset`、`.yaml` 数据文件
- 查找角色子目录中的场景/预制件文件

**物品 / 装备 / 战利品：**
- Glob `assets/data/**/items/**`、`assets/data/**/equipment/**`、`assets/data/**/loot/**`
- 查找 `.json`、`.tres`、`.asset` 数据文件

**能力 / 技能 / 法术：**
- Glob `assets/data/**/abilities/**`、`assets/data/**/skills/**`、`assets/data/**/spells/**`
- 查找 `.json`、`.tres`、`.asset` 数据文件

**对话 / 交谈 / 过场动画：**
- Glob `assets/**/*.dialogue`、`assets/**/*.csv`、`assets/**/*.ink`
- 在 `assets/data/` 中 grep 对话数据文件

**任务 / 使命：**
- Glob `assets/data/**/quests/**`、`assets/data/**/missions/**`
- 查找 `.json`、`.yaml` 定义文件

**引擎特定说明（在报告中注明）：**
- 计数为近似值——本技能无法完美解析每种引擎格式，也无法区分纯编辑器文件和已发布内容
- 场景文件可能同时包含游戏内容和系统/UI 场景；扫描会统计所有匹配项并注明此限制

---

## 第三阶段 — 差距报告

生成差距表：

```
| 系统 | 内容类型 | 指定数量 | 已找到 | 差距 | 状态 |
|--------|-------------|-----------|-------|-----|--------|
```

**状态分类：**
- `COMPLETE` — 已找到 ≥ 指定数量（100% 或以上）
- `IN PROGRESS` — 已找到为指定数量的 50–99%
- `EARLY` — 已找到为指定数量的 1–49%
- `NOT STARTED` — 已找到为 0

**优先级标记：**
在报告中标记系统为 `HIGH PRIORITY`，如果：
- 状态为 `NOT STARTED` 或 `EARLY`，且
- 该系统在系统索引中被标记为 MVP 或垂直切片（Vertical Slice），或
- 系统索引显示该系统正在阻塞下游系统

**摘要行：**
- 指定的内容项总数（Specified 列数值之和）
- 已找到的内容项总数（Found 列数值之和）
- 总体差距百分比：`(Specified - Found) / Specified * 100`

---

## 第四阶段 — 输出

### 全面审计和单系统模式

向用户展示差距表和摘要。询问："May I write the full report to `docs/content-audit-[YYYY-MM-DD].md`?"

如果同意，写入文件：

```markdown
# Content Audit — [Date]

## Summary
- **Total specified**: [N] content items across [M] systems
- **Total found**: [N]
- **Gap**: [N] items ([X%] unimplemented)
- **Scope**: [Full audit | System: name]

> Note: Counts are approximations based on file scanning.
> The audit cannot distinguish shipped content from editor/test assets.
> Manual verification is recommended for any HIGH PRIORITY gaps.

## Gap Table

| System | Content Type | Specified | Found | Gap | Status |
|--------|-------------|-----------|-------|-----|--------|

## HIGH PRIORITY Gaps

[List systems flagged HIGH PRIORITY with rationale]

## Per-System Breakdown

### [System Name]
- **GDD**: `design/gdd/[file].md`
- **Content types audited**: [list]
- **Notes**: [any caveats about scan accuracy for this system]

## Recommendation

Focus implementation effort on:
1. [Highest-gap HIGH PRIORITY system]
2. [Second system]
3. [Third system]

## Unspecified Content Counts

The following GDDs describe content without giving explicit counts.
Consider adding counts to improve auditability:
[List of GDDs and content types with "Unspecified"]
```

写入报告后，询问：

> "Would you like to create backlog stories for any of the content gaps?"

如果是：对于用户选择的每个系统，建议故事标题并引导他们使用 `/create-stories [epic-slug]` 或 `/quick-design`，具体取决于差距的大小。

### --summary 模式

直接将差距表和摘要打印到对话中。不写入文件。以"Run `/content-audit` without `--summary` to write the full report."结束。

---

## 第五阶段 — 后续步骤

审计后，推荐最有价值的后续行动：

- 如果任何系统为 `NOT STARTED` 且被标记为 MVP → "Run `/design-system [name]` to add missing content counts to the GDD before implementation begins."
- 如果总差距 >50% → "Run `/sprint-plan` to allocate content work across upcoming sprints."
- 如果需要积压故事 → "Run `/create-stories [epic-slug]` for each HIGH PRIORITY gap."
- 如果使用了 `--summary` → "Run `/content-audit` (no flag) to write the full report to `docs/`."

结论：**COMPLETE** — 内容审计完成。
