---
name: story-readiness
description: "验证故事文件是否已为实施就绪。检查嵌入的GDD需求、ADR引用、引擎说明、清晰的验收标准以及无未解决的设计问题。生成带有具体差距的 READY / NEEDS WORK / BLOCKED 判定。当用户询问'这个故事准备好了吗'、'我可以开始做这个故事吗'、'故事 X 可以开始实施了吗'时使用。"
argument-hint: "[story-file-path or 'all' or 'sprint']"
user-invocable: true
allowed-tools: Read, Glob, Grep, AskUserQuestion, Task

---


# 故事就绪度 (Story Readiness)

此技能验证故事文件包含开发者开始实现所需的一切——无冲刺中期设计中断、无猜测、无模糊的验收标准。在分配故事前运行它。

**此技能为只读。** 它从不编辑故事文件。它报告发现结果并询问用户是否需要帮助填补空白。

**输出：** 每个故事的判定（READY / NEEDS WORK / BLOCKED）及每个未就绪故事的具体差距列表。

---

## 阶段 0：确定审查模式

在启动时一次确定审查模式（存储用于本轮所有关卡调用）：

1. 如果技能以 `--review [full|lean|solo]` 调用 → 使用该值
2. 否则读取 `production/review-mode.txt` → 使用该值
3. 否则 → 默认使用 `lean`

完整的检查模式和模式定义参见 `.claude/docs/director-gates.md`。

---

## 1. 解析参数

**范围：** `$ARGUMENTS[0]`（空白 = 通过 AskUserQuestion 询问用户）

- **特定路径**（例如 `/story-readiness production/epics/combat/story-001-basic-attack.md`）：
  验证单个故事文件。
- **`sprint`**：从 `production/sprints/` 读取当前冲刺计划（最近的文件），提取其引用的每个故事路径，逐个验证。
- **`all`**：glob 搜索 `production/epics/**/*.md`，排除 `EPIC.md` 索引文件，验证找到的每个故事文件。
- **无参数**：询问用户要验证的范围。

如果未给出参数，使用 `AskUserQuestion`：
- "你想要验证什么？"
  - 选项："一个特定的故事文件"、"当前冲刺中的所有故事"、
    "production/epics/ 中的所有故事"、"特定史诗的故事"

在继续前报告范围："正在验证 [N] 个故事文件。"

---

## 2. 加载支持上下文

在检查任何故事之前，一次加载参考文档（而非每个故事加载）：

- `design/gdd/systems-index.md` — 了解哪些系统有已批准的 GDD
- `docs/architecture/control-manifest.md` — 了解存在哪些清单规则
  （如果文件不存在，注明一次缺失；不要为每个故事重复标记）
  如果文件存在，同时从头部块提取 `Manifest Version:` 日期。
- `docs/architecture/tr-registry.yaml` — 按 `id` 索引所有条目。用于验证故事中的 TR-ID。如果文件不存在，注明一次；TR-ID 检查将为所有故事自动通过（注册表先于故事，因此缺失的注册表意味着故事来自引入 TR 追踪之前）。
- 所有 ADR 状态字段 — 对于被检查故事引用的每个唯一 ADR，读取 ADR 文件并注明其 `Status:` 字段。缓存这些结果，以免为每个故事重新读取同一个 ADR。
- 当前冲刺文件（如果范围是 `sprint`）— 用于识别 Must Have / Should Have 优先级以进行升级决策

---

## 3. 故事就绪检查清单

对于每个故事文件，评估以下每个项目。故事只有在所有项目都通过或明确标记为 N/A 并附有说明的原因时才是 READY。

### 设计完整性

- [ ] **引用了 GDD 需求**：故事包含 `design/gdd/` 路径，并引用或链接了该 GDD 中的特定需求、验收标准或规则——不仅仅是 GDD 文件名。链接到文档而未追溯到特定需求不通过。
- [ ] **需求是自包含的**：故事中的验收标准无需打开 GDD 即可理解。开发者不应需要阅读单独文档来理解 DONE 的含义。
- [ ] **验收标准是可测试的**：每个标准是一个具体的、可观察的条件——而不是"实现 X"或"系统正常工作"。糟糕示例："实现跳跃机制。"良好示例："跳跃在按住跳跃键时在 0.3 秒内达到最大高度 5 个单位。"
- [ ] **验收标准不需要判断** *（对于 `Type: Visual/Feel` 自动通过）*：诸如"感觉响应灵敏"或"看起来不错"之类的标准在没有定义基准的情况下不可测试。对于 Logic、Integration、UI 和 Config/Data 故事，这些必须替换为具体的可观察条件。对于 Visual/Feel 故事，主观标准是预期的，此检查自动通过——而是验证每个主观标准都有配对的试玩测试协议或证据要求（例如"证据文档需位于 `production/qa/evidence/[slug]-evidence.md`"）。如果验收标准以或附带明确引用文件路径（如 `production/qa/evidence/[slug]-evidence.md`）结束，则为 PASS。如果标准纯粹是主观的且未指定证据文件路径，则为 NEEDS WORK。

### 架构完整性

- [ ] **引用了 ADR 或声明 N/A**：故事引用至少一个 ADR，或明确声明"不适用任何 ADR"并附有简要原因。没有 ADR 引用且没有明确 N/A 备注的故事不通过此检查。
- [ ] **ADR 是 Accepted（而非 Proposed）**：对于每个引用的 ADR，使用第 2 节中加载的缓存 ADR 状态检查其 `Status:` 字段。
  - 如果 `Status: Accepted` → 通过。
  - 如果 `Status: Proposed` → **BLOCKED**：ADR 在通过前可能会改变，故事的实现指导可能是错误的。
    修复方法：`BLOCKED：ADR-NNNN 是 Proposed — 在通过前等待接受后再实施。`
  - 如果 ADR 文件不存在 → **BLOCKED**：引用的 ADR 缺失。
  - 如果故事有明确的"不适用任何 ADR"的 N/A 备注，则自动通过。
- [ ] **TR-ID 有效且活跃**：如果故事包含 `TR-[system]-NNN` 引用，在第 2 节加载的 TR 注册表中查找它。
  - 如果 ID 存在且 `status: active` → 通过。
  - 如果 ID 存在且 `status: deprecated` 或 `status: superseded-by: ...` → NEEDS WORK：该需求已被移除或替换。
    修复方法：更新故事以引用当前需求 ID，如果不再适用则移除。
  - 如果 ID 在注册表中不存在 → NEEDS WORK：ID 未注册（故事可能早于注册表，或注册表需要运行 `/architecture-review`）。
  - 如果故事没有 TR-ID 引用或注册表不存在，则自动通过。
- [ ] **清单版本是最新的**：如果故事标题中有 `Manifest Version:` 日期，且 `docs/architecture/control-manifest.md` 存在：
  - 如果故事版本与当前清单的 `Manifest Version:` 匹配 → 通过。
  - 如果故事版本早于当前清单 → NEEDS WORK：可能有新规则适用。修复方法：审查更改的清单规则，如果有任何禁止/必需的条目发生变化则更新故事，然后将故事的 `Manifest Version:` 更新为当前版本。
  - 如果故事没有 `Manifest Version:` 字段或清单不存在，则自动通过。
- [ ] **引擎注意事项存在**：对于此故事可能触及的任何超出知识截止日期的引擎 API，包含实现说明或验证要求。如果故事明确不涉及引擎 API（例如，纯粹的数据/配置更改），"N/A — 不涉及引擎 API"是可以接受的。
- [ ] **注明了控制清单规则**：引用了控制清单中的相关层级规则，或声明了"N/A — 清单尚未创建"。如果 `docs/architecture/control-manifest.md` 尚不存在，此项自动通过（不惩罚在清单创建前编写的故事）。

### 范围清晰度

- [ ] **预估存在**：故事包含规模预估（小时、点数或 T 恤尺码）。没有预估的故事无法规划。
- [ ] **声明了范围内/范围外边界**：故事说明它**不**包含的内容，要么在明确的 Out of Scope 部分中，要么以明确边界的措辞表达。没有这个，实现过程中的范围蔓延是可能的。
- [ ] **列出了故事依赖项**：如果此故事依赖于其他故事先完成，则列出这些故事的 ID。如果没有依赖项，明确声明"无"（而不仅仅是省略）。

### 未解决问题

- [ ] **无未解决的设计问题**：故事在任何验收标准、实现说明或规则声明中不包含标记为"UNRESOLVED"、"TBD"、"TODO"、"? "或等效标记的文本。
- [ ] **依赖故事不是 DRAFT**：对于列为依赖项的每个故事，检查文件是否存在且不是 DRAFT 状态。依赖 DRAFT 或缺失故事的故事是 BLOCKED 而非仅 NEEDS WORK。

### 资产引用检查

- [ ] **引用的资产存在**：扫描故事文本中的资产路径模式（包含 `assets/` 的路径，或扩展名为 `.png`、`.jpg`、`.svg`、`.wav`、`.ogg`、`.mp3`、`.glb`、`.gltf`、`.tres`、`.tscn`、`.res` 的文件）。
  - 对于找到的每个资产路径：使用 Glob 检查文件是否存在。
  - 如果任何引用的资产不存在：**NEEDS WORK** — 注明缺失的路径。（故事引用了尚未创建的资产。要么移除引用，创建占位符，要么将其标记为对资产创建故事的明确依赖。）
  - 如果所有引用的资产都存在：注明"已验证的引用资产：找到 [count] 个。"
  - 如果故事中没有引用资产路径：注明"故事中未找到资产引用 — 跳过资产检查。"此项自动通过。
  - 这仅是存在性检查。不验证文件格式或内容。

### 完成定义

- [ ] **按故事类型的最低可测试验收标准**：
  - Logic / Integration 故事：至少 3 个
  - Visual/Feel 和 UI 故事：至少 2 个
  - Config/Data 故事：至少 1 个
  应用匹配故事 `Type:` 字段的阈值。如果故事少于最低数量，标记为 NEEDS WORK。
- [ ] **如适用，注明了性能预算**：如果此故事涉及游戏循环、渲染或物理的任何部分，存在性能预算或"预计无性能影响 — [原因]"备注。
- [ ] **声明了故事类型**：故事在其标题中包含 `Type:` 字段，标识测试类别（Logic / Integration / Visual/Feel / UI / Config/Data）。没有这个，在故事关闭时无法强制执行测试证据要求。修复方法：在故事标题中添加 `Type: [Logic|Integration|Visual/Feel|UI|Config/Data]`。
- [ ] **测试证据要求明确**：如果设置了故事类型，故事包含一个 `## Test Evidence` 部分，说明证据将存储在哪里（Logic/Integration 的测试文件路径，或 Visual/Feel/UI 的证据文档路径）。修复方法：添加 `## Test Evidence`，其中包含故事类型预期的证据位置。

---

## 4. 判定分配

为每个故事分配三种判定之一：

**READY（就绪）** — 所有检查清单项目均通过或有明确的 N/A 理由。故事可以立即分配。

**NEEDS WORK（需修改）** — 一个或多个检查清单项目未通过，但所有依赖故事存在且不是 DRAFT。故事可以在分配前修复。

**BLOCKED（阻塞）** — 一个或多个依赖故事缺失或是 DRAFT 状态，或关键设计问题（在标准或规则中标记为 UNRESOLVED）没有负责人。在阻塞项解决前不能分配故事。注意：BLOCKED 的故事可能同时有 NEEDS WORK 项目——两者都列出。

---

## 5. 输出格式

### 单个故事输出

```
## Story Readiness：[故事标题]
File：[路径]
Verdict：[READY / NEEDS WORK / BLOCKED]

### 通过的检查（N/[总数]）
[简要列出通过的项目]

### 差距
- [检查清单项目]：[缺失或错误的精确描述]
  修复方法：[解决此差距所需的具体文本]

### 阻塞项（如果 BLOCKED）
- [阻塞内容]：[必须首先解决的故事 ID 或设计问题]
```

### 多个故事汇总输出

```
## Story Readiness Summary — [范围] — [日期]

Ready:      [N] 个故事
Needs Work: [N] 个故事
Blocked:    [N] 个故事

### 就绪的故事
- [故事标题]（[路径]）

### 需修改的故事
- [故事标题]：[主要差距 — 一行]
- [故事标题]：[主要差距 — 一行]

### 被阻塞的故事
- [故事标题]：被 [故事 ID / 设计问题] 阻塞

---
[每个未就绪故事的完整详情紧随其后，使用单个故事格式]
```

### 冲刺升级

如果范围是 `sprint` 且任何 Must Have 故事是 NEEDS WORK 或 BLOCKED，在输出顶部添加一个突出的警告：

```
警告：[N] 个 Must Have 故事未就绪可实施。
[列出它们及其主要差距或阻塞项。
在冲刺开始前解决这些问题，或使用 `/sprint-plan update` 重新规划。
```

---

## 6. 协作协议

此技能为只读。它从不对编辑提出建议或请求写入文件。

在报告发现后，提供：

"需要帮助填充这些故事的空白吗？我可以为你起草缺失的部分以供批准。"

如果用户对特定故事说"是"，仅在对话中起草缺失的部分。不要使用 Write 或 Edit 工具——用户（或 `/create-stories`）负责编写。

**重定向规则：**
- 如果故事文件完全不存在："此故事文件完全缺失。运行 `/create-epics [layer]`，然后 `/create-stories [epic-slug]` 以从 GDD 和 ADR 生成故事。"
- 如果故事没有 GDD 引用且工作看起来很小："此故事没有 GDD 引用。如果变更很小（约 4 小时以内），运行 `/quick-design [description]` 创建快速设计规范，然后在故事中引用该规范。"
- 如果故事的范围已超出其原始规模："此故事似乎已扩大了范围。考虑拆分或在实施开始前上报给制作人。"

---

## 7. 下一个故事交接

在完成单个故事的就绪度检查后（非 `all` 或 `sprint` 范围）：

1. 从 `production/sprints/` 读取当前冲刺文件（最近的文件）。
2. 找到符合以下条件的故事：
   - 状态：READY 或 NOT STARTED
   - 不是刚刚检查的故事
   - 未被未完成的依赖项阻塞
   - 在 Must Have 或 Should Have 层级中

如果找到任何故事，最多显示 3 个：

```
### 此冲刺中的其他就绪故事

1. [故事名称] — [一行描述] — 预估：[X 小时]
2. [故事名称] — [一行描述] — 预估：[X 小时]

在开始前运行 `/story-readiness [path]` 以验证。
```

如果不存在冲刺文件或未找到其他就绪故事，静默跳过此部分。

---

## 阶段 8：主管关卡——故事就绪度审查

在启动 QL-STORY-READY 前应用阶段 0 中确定的审查模式：

- `solo` → 跳过。备注："QL-STORY-READY skipped — Solo mode." 进入关闭。
- `lean` → 跳过。备注："QL-STORY-READY skipped — Lean mode." 进入关闭。
- `full` → 正常启动。

通过 Task 使用关卡 **QL-STORY-READY**（`.claude/docs/director-gates.md`）生成 `qa-lead`。

传递以下上下文：
- 故事标题
- 验收标准列表（故事验收标准部分中的所有项目）
- 依赖项状态（所有列出的依赖项及其当前状态：存在 / DRAFT / 缺失）
- 阶段 4 中的整体判定（READY / NEEDS WORK / BLOCKED）

按照 `director-gates.md` 中的标准规则处理判定：
- **ADEQUATE（充分）** → 故事已清除。进入关闭。
- **GAPS [列表]** → 通过 `AskUserQuestion` 向用户展示具体的差距：选项：`用建议的差距更新故事` / `接受并继续` / `进一步讨论`。
- **INADEQUATE（不充分）** → 展示具体差距；询问用户是否更新故事或继续。

---

## 推荐后续步骤

- 运行 `/dev-story [story-path]` 一旦故事 READY 就开始实现
- 运行 `/story-readiness sprint` 一次检查当前冲刺中的所有故事
- 如果故事文件完全缺失，运行 `/create-stories [epic-slug]`
