---
name: help
description: "分析已完成的工作和用户的查询，并就下一步操作提供建议。当用户询问下一步该做什么、现在该做什么、卡住了或不知道该怎么办时使用"
argument-hint: "[可选：你刚刚完成的事情，例如'完成了设计评审'或'卡在 ADR 上']"
user-invocable: true
allowed-tools: Read, Glob, Grep
context: |
  !echo "=== Live Project State ===" && echo "Stage: $(cat production/stage.txt 2>/dev/null | tr -d '[:space:]' || echo 'not set')" && echo "Latest sprint: $(ls -t production/sprints/*.md 2>/dev/null | head -1 || echo 'none')" && echo "Session state: $(head -5 production/session-state/active.md 2>/dev/null || echo 'none')"
---


# Studio Help — 下一步该做什么？

本 skill 为只读——它报告发现但不写入任何文件。

本 skill 会准确判断你在游戏开发管线中的位置，并告诉你接下来该做什么。它是**轻量级**的——不是完整的审计。如需完整的差距分析，请使用 `/project-stage-detect`。

---

## 步骤 1：读取目录

读取 `.claude/docs/workflow-catalog.yaml`。这是所有阶段及其步骤（按顺序）、每个步骤是必需还是可选、以及指示完成状态的文件模式（artifact globs）的权威列表。

---

## 步骤 1b：查找目录中未收录的 Skill

读取目录后，使用 Glob 查找 `.claude/skills/*/SKILL.md` 以获取已安装 skill 的完整列表。对于每个文件，提取其 frontmatter 中的 `name:` 字段。

与目录中的 `command:` 值进行比较。任何名称未作为目录命令出现的 skill 都是**未收录的 skill**——仍可使用但不属于阶段门控工作流程的一部分。

将它们收集起来，在步骤 7 的输出中以页脚块的形式展示：

```
### 额外已安装（不在工作流程中）
- `/skill-name` — [来自 SKILL.md frontmatter 的描述]
- `/skill-name` — [描述]
```

仅当存在至少一个未收录的 skill 时才显示此块。根据用户当前阶段限制为最相关的 10 个（生产阶段的相关技能、生产/打磨阶段的团队技能等）。

---

## 步骤 2：确定当前阶段

按以下顺序检查：

1. **读取 `production/stage.txt`**——如果存在且有内容，则这是权威的阶段名称。将其映射到目录阶段键：
   - "Concept"（概念） → `concept`
   - "Systems Design"（系统设计） → `systems-design`
   - "Technical Setup"（技术搭建） → `technical-setup`
   - "Pre-Production"（前期制作） → `pre-production`
   - "Production"（制作） → `production`
   - "Polish"（打磨） → `polish`
   - "Release"（发布） → `release`

2. **如果 stage.txt 不存在**，则根据工件推断阶段（最先进匹配胜出）：
   - `src/` 有 10 个以上源文件 → `production`
   - `production/stories/*.md` 存在 → `pre-production`
   - `docs/architecture/adr-*.md` 存在 → `technical-setup`
   - `design/gdd/systems-index.md` 存在 → `systems-design`
   - `design/gdd/game-concept.md` 存在 → `concept`
   - 什么都没有 → `concept`（新项目）

---

## 步骤 3：读取会话上下文

如果存在，读取 `production/session-state/active.md`。提取：
- 最近正在处理的内容
- 任何进行中的任务或未解决的问题
- 来自 STATUS 块的当前史诗/功能/任务（如果存在）

这告诉你用户刚刚完成或卡在了哪里——用于个性化输出。

---

## 步骤 4：检查当前阶段的步骤完成情况

对于当前阶段中的每个步骤（来自目录）：

### 基于工件的检查

如果步骤有 `artifact.glob`：
- 使用 Glob 检查是否存在匹配该模式的文件
- 如果指定了 `min_count`，验证至少有那么多文件匹配
- 如果指定了 `artifact.pattern`，使用 Grep 验证模式存在于匹配的文件中
- **已完成** = 满足工件条件
- **未完成** = 工件缺失或未找到模式

如果步骤有 `artifact.note`（无 glob）：
- 标记为 **手动**——无法自动检测，将询问用户

如果步骤没有 `artifact` 字段：
- 标记为 **未知**——完成状态不可追踪（例如可重复的实现工作）

### 特殊情况：production 阶段——读取 `sprint-status.yaml`

当当前阶段是 `production` 时，在执行基于 glob 的故事检查之前，先检查 `production/sprint-status.yaml` 是否存在。如果存在，直接读取：

- `status: in-progress`（进行中）的故事 → 显示为"当前活跃"
- `status: ready-for-dev`（准备开发）的故事 → 显示为"下一个"
- `status: done`（已完成）的故事 → 计为完成
- `status: blocked`（阻塞）的故事 → 使用 `blocker` 字段显示为阻塞项

这提供了精确的逐个故事状态，无需扫描 markdown。跳过 `implement` 和 `story-done` 步骤的 glob 工件检查——YAML 是权威来源。

### 特殊情况：`repeatable: true`（非生产阶段）

对于 production 之外的可重复步骤（例如"系统 GDD"），工件检查仅告诉你是否有*任何*工作已完成，而非是否已全部完成。以不同方式标记——显示已检测到的内容，然后注明可能仍在进行中。

---

## 步骤 5：定位并确定后续步骤

根据完成数据，确定：

1. **最后确认完成的步骤**——最远的已完成必需步骤
2. **当前阻塞项**——第一个未完成的*必需*步骤（这是用户下一步必须做的）
3. **可选机会**——未完成的*可选*步骤，可以在阻塞项之前或与其并行完成
4. **即将到来的必需步骤**——当前阻塞项之后的必需步骤（显示为"即将到来"，以便用户提前规划）

如果用户提供了参数（例如"刚完成设计评审"），使用该参数跳过他们提到的步骤，即使工件检查存在歧义。

---

## 步骤 6：检查进行中的工作

如果 `active.md` 显示有一个活跃的任务或史诗：
- 在顶部突出显示："看起来你正在处理 [X]"
- 建议继续或确认是否已完成

---

## 步骤 7：呈现输出

保持**简短直接**。这是快速指引，而非报告。

```
## 你现在的位置：[阶段标签]

**进行中：** [来自 active.md，如果有]

### ✓ 已完成
- [已完成的步骤名称]
- [已完成的步骤名称]

### → 下一步（必需）
**[步骤名称]** — [描述]
命令：`[/command]`

### ~ 也可用（可选）
- **[步骤名称]** — [描述] → `/command`
- **[步骤名称]** — [描述] → `/command`

### 之后即将到来
- [下一个必需步骤名称]（`/command`）
- [下一个必需步骤名称]（`/command`）

---
即将接近 **[下一阶段]** 门控 → 准备好后运行 `/gate-check`。
```

**格式规则：**
- `✓` 表示已确认完成
- `→` 表示当前必需的下一步（只有一个——第一个阻塞项）
- `~` 表示当前可用的可选步骤
- 命令以内联反引号代码显示
- 如果步骤没有命令（例如"实现故事"），说明该做什么而不是显示斜杠命令
- 对于手动步骤，询问用户："我无法判断 [步骤] 是否已完成——它完成了吗？"

裁决：**完成**——已识别后续步骤。

---

## 步骤 8：门控警告（如果接近）

在当前阶段的步骤之后，检查用户是否可能接近门控：
- 如果当前阶段中所有必需步骤都已完成（或接近完成），添加："你已接近 **[当前阶段] → [下一阶段]** 的门控。准备好后运行 `/gate-check`。"
- 如果多个必需步骤仍待完成，则跳过门控警告——目前还不相关。

---

## 步骤 9：升级路径

在建议之后，如果用户看起来卡住或困惑，添加：

```
---
需要更多细节？
- `/project-stage-detect` — 完整的差距分析，列出所有缺失的工件
- `/gate-check` — 下一阶段的正式就绪检查
- `/start` — 从头开始重新定位
```

仅当用户的输入暗示困惑时才显示（例如"我不知道"、"卡住了"、"迷路了"、"不确定"）。对于简单的"下一步是什么？"查询不要显示。

---

## 协作协议

- **决不要自动运行下一个技能。** 推荐它，让用户自行调用。
- **手动步骤要询问**，而不是假设已完成或未完成。
- **匹配用户的语气**——如果他们听起来有压力（"我完全迷路了"），给予安抚，给出一个操作建议，而不是列出六项。
- **一条主要建议**——用户离开时应该确切知道接下来该做一件事。可选步骤和"即将到来"是次要信息。
