---
name: consistency-check
description: "扫描所有 GDD 与实体注册表，检测跨文档不一致问题：同一实体具有不同属性、同一物品具有不同数值、同一公式具有不同变量。采用 grep 优先的方法——先读取注册表，然后仅针对存在冲突的 GDD 章节进行读取，避免完整读取文档。"
argument-hint: "[full | since-last-review | entity:<name> | item:<name>]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, AskUserQuestion

---


# 一致性检查（Consistency Check）

通过将所有 GDD 与实体注册表（`design/registry/entities.yaml`）进行比较，检测跨文档不一致问题。采用 grep 优先的方法：读取注册表一次，然后仅针对提及已注册名称的 GDD 章节进行定向读取——除非发现冲突需要调查，否则不做完整文档读取。

**本技能是写入时的安全网。**它捕获了 `/design-system` 的每章节检查可能遗漏的问题，以及 `/review-all-gdds` 的整体审查可能发现得太晚的问题。

**运行时机：**
- 在编写完每个新 GDD 之后（在进入下一个系统之前）
- 在 `/review-all-gdds` 之前（以便该技能从干净的基线开始）
- 在 `/create-architecture` 之前（不一致问题会污染下游的 ADR）
- 按需运行：`/consistency-check entity:[name]` 专门检查一个实体

**输出：** 冲突报告 + 可选的注册表修正

---

## 第一阶段：解析参数并加载注册表

**模式：**
- 无参数 / `full` — 检查所有注册条目与所有 GDD
- `since-last-review` — 仅检查自上次审查报告以来被修改的 GDD
- `entity:<name>` — 在所有 GDD 中检查一个特定实体
- `item:<name>` — 在所有 GDD 中检查一个特定物品

**加载注册表：**

```
Read path="design/registry/entities.yaml"
```

如果文件不存在或没有条目：
> "Entity registry is empty. Run `/design-system` to write GDDs — the registry is populated automatically after each GDD is completed. Nothing to check yet."

停止并退出。

从注册表构建四个查找表：
- **entity_map**：`{ name → { source, attributes, referenced_by } }`
- **item_map**：`{ name → { source, value_gold, weight, ... } }`
- **formula_map**：`{ name → { source, variables, output_range } }`
- **constant_map**：`{ name → { source, value, unit } }`

统计已注册条目的总数。报告：
```
Registry loaded: [N] entities, [N] items, [N] formulas, [N] constants
Scope: [full | since-last-review | entity:name]
```

---

## 第二阶段：定位范围内的 GDD

```
Glob pattern="design/gdd/*.md"
```

排除：`game-concept.md`、`systems-index.md`、`game-pillars.md`——这些不是系统 GDD。

对于 `since-last-review` 模式：
```bash
git log --name-only --pretty=format: -- design/gdd/ | grep "\.md$" | sort -u
```
仅限自最近一个 `design/gdd/gdd-cross-review-*.md` 文件创建日期以来被修改的 GDD。

在扫描前报告范围内的 GDD 列表。

---

## 第三阶段：Grep 优先的冲突扫描

对于每个注册条目，在每个范围内的 GDD 中 grep 该条目的名称。**不要进行完整读取**——仅提取匹配行及其前后上下文（-C 3 行）。

这是核心优化：与其读取 10 个 GDD × 每份 400 行（共 4,000 行），不如 grep 50 个实体名 × 10 个 GDD（共 50 次定向搜索，每次命中返回约 10 行）。

### 3a：实体扫描

对于 entity_map 中的每个实体：

```
Grep pattern="[entity_name]" glob="design/gdd/*.md" output_mode="content" -C 3
```

对于每个命中的 GDD，提取实体名称附近提到的数值：
- 任何数值属性（数量、成本、持续时间、范围、比率）
- 任何分类属性（类型、层级、类别）
- 任何派生值（总计、输出、结果）
- 任何在 entity_map 中注册的其他属性

将提取的值与注册表条目进行比较。

**冲突检测：**
- 注册表称 `[entity_name].[attribute] = [value_A]`。GDD 称 `[entity_name] has [value_B]`。→ **冲突（CONFLICT）**
- 注册表称 `[item_name].[attribute] = [value_A]`。GDD 称 `[item_name] is [value_B]`。→ **冲突（CONFLICT）**
- GDD 提到了 `[entity_name]` 但未指定该属性。→ **备注（NOTE）**（无冲突，仅无法验证）

### 3b：物品扫描

对于 item_map 中的每个物品，在所有 GDD 中 grep 物品名称。提取：
- 售价/价值/金币价值
- 重量
- 堆叠规则（可堆叠/不可堆叠）
- 类别

与注册表条目数值进行比较。

### 3c：公式扫描

对于 formula_map 中的每个公式，在所有 GDD 中 grep 公式名称。提取：
- 公式附近提到的变量名
- 提到的输出范围或上限值

与注册表条目进行比较：
- 不同的变量名 → **冲突（CONFLICT）**
- 输出范围不同 → **冲突（CONFLICT）**

### 3d：常量扫描

对于 constant_map 中的每个常量，在所有 GDD 中 grep 常量名称。提取：
- 常量名称附近提到的任何数值

与注册表值进行比较：
- 不同的数字 → **冲突（CONFLICT）**

---

## 第四阶段：深入调查（仅限冲突）

对于第三阶段中发现的每个冲突，对冲突 GDD 进行定向的完整章节读取，以获取精确的上下文：

```
Read path="design/gdd/[conflicting_gdd].md"
```
（如果文件较大，可使用带更宽上下文的 Grep）

用完整上下文确认冲突。确定：
1. **哪个 GDD 是正确的？**检查注册表中的 `source:` 字段——源 GDD 是权威所有者。任何与之矛盾的其他 GDD 是需要更新的那个。
2. **注册表本身是否过时了？**如果源 GDD 在注册表条目写入之后被更新过（检查 git log），注册表可能已过时。
3. **这是有意的设计变更吗？**如果冲突代表有意的设计决策，解决方案是：更新源 GDD，更新注册表，然后修复所有其他 GDD。

对于每个冲突，进行分类：
- **🔴 冲突（CONFLICT）**——同一个命名的实体/物品/公式/常量在不同 GDD 中具有不同数值。必须在架构开始前解决。
- **⚠️ 过期注册表（STALE REGISTRY）**——源 GDD 值已更改但注册表未更新。注册表需要更新；其他 GDD 可能已经正确。
- **ℹ️ 无法验证（UNVERIFIABLE）**——提到了实体但未声明可比较的属性。不是冲突，仅记录引用。

---

## 第五阶段：输出报告

```
## Consistency Check Report
Date: [date]
Registry entries checked: [N entities, N items, N formulas, N constants]
GDDs scanned: [N] ([list names])

---

### Conflicts Found (must resolve before architecture)

🔴 [Entity/Item/Formula/Constant Name]
   Registry (source: [gdd]): [attribute] = [value]
   Conflict in [other_gdd].md: [attribute] = [different_value]
   → Resolution needed: [which doc to change and to what]

---

### Stale Registry Entries (registry behind the GDD)

⚠️ [Entry Name]
   Registry says: [value] (written [date])
   Source GDD now says: [new value]
   → Update registry entry to match source GDD, then check referenced_by docs.

---

### Unverifiable References (no conflict, informational)

ℹ️ [gdd].md mentions [entity_name] but states no comparable attributes.
   No conflict detected. No action required.

---

### Clean Entries (no issues found)

✅ [N] registry entries verified across all GDDs with no conflicts.

---

Verdict: PASS | CONFLICTS FOUND
```

**结论：**
- **通过（PASS）**——无冲突。注册表和 GDD 在所有检查的数值上一致。
- **发现冲突（CONFLICTS FOUND）**——检测到一个或多个冲突。列出解决步骤。

---

## 第六阶段：注册表修正

如果发现过期的注册表条目，询问：
> "May I update `design/registry/entities.yaml` to fix the [N] stale entries?"

对于每个过期条目：
- 更新 `value` / 属性字段
- 设置 `revised:` 为今天的日期
- 添加 YAML 注释记录旧值：`# was: [old_value] before [date]`

如果在 GDD 中发现了不在注册表中的新条目，询问：
> "Found [N] entities/items mentioned in GDDs that aren't in the registry yet.
> May I add them to `design/registry/entities.yaml`?"

仅添加出现在多个 GDD 中的条目（真正的跨系统事实）。

**绝不删除注册表条目。**如果某个条目从所有 GDD 中被移除，将其设置为 `status: deprecated`。

写入后：结论：**COMPLETE** — 一致性检查完成。
如果冲突仍未解决：结论：**BLOCKED** — 在架构开始前，[N] 个冲突需要手动解决。

### 6b：追加到反思日志

如果发现了任何 🔴 冲突条目（无论是否已解决），为每个冲突向 `docs/consistency-failures.md` 追加一条条目：

```markdown
### [YYYY-MM-DD] — /consistency-check — 🔴 CONFLICT
**Domain**: [system domain(s) involved]
**Documents involved**: [source GDD] vs [conflicting GDD]
**What happened**: [specific conflict — entity name, attribute, differing values]
**Resolution**: [how it was fixed, or "Unresolved — manual action needed"]
**Pattern**: [generalised lesson, e.g. "Item values defined in combat GDD were not
referenced in economy GDD before authoring — always check entities.yaml first"]
```

如果 `docs/consistency-failures.md` 不存在，在追加前用以下头部创建它：

```markdown
# Consistency Failure Log

<!-- Auto-maintained by /consistency-check. Do not edit manually. -->
<!-- One entry per detected conflict, in chronological order. -->

| Date | GDD A | GDD B | Conflict Type | Status |
|------|-------|-------|---------------|--------|
```

然后追加新的冲突条目。绝不跳过日志记录——文件不存在不是丢失冲突历史的原因。

---

## 第七阶段：会话状态与收尾

静默追加到 `production/session-state/active.md`（如果文件不存在则创建）：

```
<!-- CONSISTENCY-CHECK: [date] | GDDs checked: [N] | Conflicts found: [N] | Report: docs/consistency-report-[date].md -->
```

然后使用 `AskUserQuestion` 小部件关闭：

- **提示**："Consistency check complete — [N] conflicts found. What next?"
- **选项**：
  - `[A] Fix the highest-priority conflict now`
  - `[B] Save full report and stop`
  - `[C] Run /design-review on the most conflicted GDD`
  - `[D] Stop here`

切勿以纯文本结束技能。始终使用此小部件关闭。

---

## 恢复/参考

- **如果通过（PASS）**：运行 `/review-all-gdds` 进行整体设计理论审查，如果所有 MVP GDD 都已完成则运行 `/create-architecture`。
- **如果发现冲突（CONFLICTS FOUND）**：修复标记的 GDD，然后重新运行 `/consistency-check` 以确认解决。
- **如果注册表过期（STALE REGISTRY）**：更新注册表（第六阶段），然后重新运行以验证。
- **在编写每个新 GDD 之后**运行 `/consistency-check` 以尽早发现问题的习惯，而不是等到架构阶段。
