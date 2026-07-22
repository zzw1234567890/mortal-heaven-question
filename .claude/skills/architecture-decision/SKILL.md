---
name: architecture-decision
description: "创建架构决策记录（ADR），记录重要的技术决策、其上下文、考虑过的替代方案及后果。每个重大技术选择都应该有 ADR。"
argument-hint: "[title] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Task, AskUserQuestion

---


当此技能被调用时：

## 0. 解析参数——检测改造模式

解析审查模式（一次性完成，为本运行的所有关卡生成存储）：
1. 如果传入了 `--review [full|lean|solo]` → 使用该值
2. 否则读取 `production/review-mode.txt` → 使用该值
3. 否则 → 默认为 `lean`

完整的检查模式请参见 `.claude/docs/director-gates.md`。

**如果参数以 `retrofit` 开头后跟文件路径**
（例如 `/architecture-decision retrofit docs/architecture/adr-0001-event-system.md`）：

进入**改造模式**：

1. 完整读取现有的 ADR 文件。
2. 通过扫描标题识别哪些模板部分存在：
   - `## Status` — **如果缺失则阻塞（BLOCKING）**：`/story-readiness` 无法检查 ADR 接受状态
   - `## ADR Dependencies` — 如果缺失则高（HIGH）：依赖排序中断
   - `## Engine Compatibility` — 如果缺失则高（HIGH）：截止后风险未知
   - `## GDD Requirements Addressed` — 如果缺失则中（MEDIUM）：可追溯性丢失
3. 向用户呈现：
   ```
   ## 改造：[ADR 标题]
   文件：[path]

   已存在的部分（不会被触及）：
   ✓ Status：[当前值，或"缺失——将添加"]
   ✓ [section]

   要添加的缺失部分：
   ✗ Status — 阻塞（没有这个，故事无法验证 ADR 接受状态）
   ✗ ADR Dependencies — 高（HIGH）
   ✗ Engine Compatibility — 高（HIGH）
   ```
4. 询问："是否要添加 [N] 个缺失的部分？我不会修改任何现有内容。"
5. 如果同意：
   - 对于 **Status**：询问用户——"该决定的当前状态是什么？"
     选项："Proposed"、"Accepted"、"Deprecated"、"Superseded by ADR-XXXX"
   - 对于 **ADR Dependencies**：询问——"该决定是否依赖其他 ADR？它是否启用或阻塞其他 ADR 或史诗？" 每个字段接受"None"。
   - 对于 **Engine Compatibility**：读取引擎参考文档（与下方步骤 1 相同），并请用户确认领域。然后使用已验证的数据生成表格。
   - 对于 **GDD Requirements Addressed**：询问——"哪些 GDD 系统促使了这一决定？每个 GDD 中的哪些具体需求由这个 ADR 解决？"
   - 使用 Edit 工具将每个缺失部分追加到 ADR 文件中。
   - **绝不修改任何现有部分。** 仅追加或填充缺失的部分。
6. 添加所有缺失部分后，如果 ADR 的 `## Date` 字段缺失，则更新它。
7. 建议："现在运行 `/architecture-review` 以重新验证覆盖范围，因为此 ADR 已具有其 Status 和 Dependencies 字段。"

如果不在改造模式中，继续下面的步骤 1（正常的 ADR 编写）。

**无参数保护**：如果没有提供参数（标题为空），在运行阶段 0 之前询问：

> "你在记录什么技术决策？请提供一个简短的标题（例如 `event-system-architecture`、`physics-engine-choice`）。"

使用用户的响应作为标题，然后继续步骤 1。

---

## 1. 加载引擎上下文（始终优先）

在做任何其他事情之前，建立引擎环境：

1. 读取 `docs/engine-reference/[engine]/VERSION.md` 以获取：
   - 引擎名称和版本
   - LLM 知识截止日期
   - 截止后版本风险级别（低 / 中 / 高）

2. 从标题或用户描述中识别该架构决策的**领域**。常见领域：物理、渲染、UI、音频、导航、动画、网络、核心、输入、脚本。

3. 如果存在相应的模块参考文档，读取它：
   `docs/engine-reference/[engine]/modules/[domain].md`

4. 读取 `docs/engine-reference/[engine]/breaking-changes.md` —— 标记相关领域中任何在 LLM 训练截止日期之后的更改。

5. 读取 `docs/engine-reference/[engine]/deprecated-apis.md` —— 标记相关领域中任何不应使用的 API。

6. **如果领域具有中或高风险，在继续之前显示知识缺口警告**：

   ```
   ⚠️  引擎知识缺口警告
   引擎：[name + version]
   领域：[domain]
   风险级别：高（HIGH）—— 此版本在 LLM 截止日期之后。

   从引擎参考文档验证的关键变更：
   - [与此领域相关的变更 1]
   - [变更 2]

   本 ADR 将与引擎参考库交叉引用。
   仅使用经过验证的信息进行操作——不要仅依赖训练数据。
   ```

   如果尚未配置引擎，提示："尚未配置引擎。请先运行 `/setup-engine`，或告诉我你正在使用的引擎。"

---

## 2. 确定下一个 ADR 编号

扫描 `docs/architecture/` 中现有的 ADR，找到下一个编号。

---

## 3. 收集上下文

读取 `design/gdd/` 中的相关代码、现有 ADR 和相关 GDD。

### 3a：架构注册表检查（阻塞关卡）

读取 `docs/registry/architecture.yaml`。提取与本 ADR 领域和决策相关的条目（按系统名称、领域关键词或受影响状态进行 grep）。

在协作设计开始之前，将任何相关的立场作为锁定约束呈现给用户：

```
## 现有架构立场（不得矛盾）

状态所有权：
  player_health → 由 health-system 拥有（ADR-0001）
  接口：HealthComponent.current_health（只读 float）
  → 如果本 ADR 读取或写入玩家生命值，它必须使用此接口。

接口约定：
  damage_delivery → 信号模式（ADR-0003）
  信号：damage_dealt(amount, target, is_crit)
  → 如果本 ADR 传递或接收伤害事件，它必须使用此信号。

禁止模式：
  ✗ autoload_singleton_coupling（ADR-0001）
  ✗ direct_cross_system_state_write（ADR-0000）
  → 提议的方法不得使用这些模式。
```

如果用户提议的决定会与任何已注册的立场矛盾，立即呈现冲突：

> "⚠️ 冲突：本 ADR 提议 [X]，但 ADR-[NNNN] 已确立 [Y] 是此目的的接受模式。在未解决此冲突的情况下继续将产生矛盾的 ADR 和不一致的故事。
> 选项：（1）与现有立场对齐，（2）使用明确的替换来取代 ADR-[NNNN]，（3）解释为什么此案例是例外。"

在冲突解决或明确接受为有意例外之前，不要继续到步骤 4（协作设计）。

---

## 4. 协作引导决策

在询问任何问题之前，从已收集的上下文中推导出技能的最佳猜测（已读取的 GDD、已加载的引擎参考、已扫描的现有 ADR）。然后使用 `AskUserQuestion` 呈现**确认/调整**提示——而不是开放式问题。

**首先推导假设：**
- **问题**：从标题 + GDD 上下文推断需要做出的决定
- **替代方案**：从引擎参考 + GDD 需求提出 2-3 个具体选项
- **依赖关系**：扫描现有 ADR 查找上游依赖；如果不明确则假设无
- **GDD 关联**：提取标题直接关联的 GDD 系统
- **状态**：新 ADR 始终为 `Proposed` —— 从不询问用户状态是什么

**假设范围说明**：假设仅涵盖：问题框架、替代方法、上游依赖、GDD 关联和状态。模式设计问题（例如"生成时机应该如何工作？"、"数据应该是内联还是外部？"）不是假设——它们是属于独立步骤的设计决策，在假设确认之后进行。

**假设确认后**，如果 ADR 涉及模式或数据设计选择，在起草之前使用单独的多标签 `AskUserQuestion` 独立询问每个设计问题。

**使用 `AskUserQuestion` 呈现假设：**

```
这是在起草前我假设的内容：

问题：[从上下文推导的一句话问题陈述]
我将考虑的替代方案：
  A）[从引擎参考推导的选项]
  B）[从 GDD 需求推导的选项]
  C）[来自常见模式的选项]
驱动此决策的 GDD 系统：[从上下文推导的列表]
依赖关系：[上游 ADR（如果有），否则"None"]
状态：Proposed

[A] 继续——按这些假设起草
[B] 更改替代方案列表
[C] 调整 GDD 关联
[D] 添加性能预算约束
[E] 需要先更改其他内容
```

在用户确认假设或提供修正之前，不要生成 ADR。

**在引擎专家和技术主管审查返回后**（步骤 5.5/5.6），如果仍有未解决的决定，将每个决定作为单独的 `AskUserQuestion` 呈现，包含提议的选项作为选择以及一个自由文本退出选项：

```
决定：[具体的未解决点]
[A] [专家审查中的选项]
[B] [替代选项]
[C] 不同的方法——我来描述
```

**ADR 依赖关系** —— 从现有 ADR 推导，然后确认：
- 该决定是否依赖于任何尚未接受的 ADR？
- 它是否解锁或解除阻塞其他 ADR 或史诗？
- 它是否阻塞任何特定的史诗启动？

在 **ADR Dependencies** 部分记录答案。如果没有约束适用，每个字段写入"None"。

---

## 5. 生成 ADR

按照以下格式：

```markdown
# ADR-[NNNN]：[标题]

## 状态
[Proposed | Accepted | Deprecated | Superseded by ADR-XXXX]

## 日期
[决定日期]

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | [例如 Godot 4.6] |
| **领域** | [物理 / 渲染 / UI / 音频 / 导航 / 动画 / 网络 / 核心 / 输入] |
| **知识风险** | [低 / 中 / 高 —— 来自 VERSION.md] |
| **查阅的参考** | [列出的引擎参考文档，例如 `docs/engine-reference/godot/modules/physics.md`] |
| **使用的截止后 API** | [本决策依赖的 LLM 截止后版本的任何 API，或"None"] |
| **需要验证** | [在发布前需要测试的具体行为，或"None"] |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | [ADR-NNNN（必须被接受后才能实现），或"None"] |
| **启用** | [ADR-NNNN（本 ADR 解锁该决定），或"None"] |
| **阻塞** | [史诗/故事名称 —— 在本 ADR 被接受之前无法开始，或"None"] |
| **排序说明** | [上述未包含的任何排序约束] |

## 上下文

### 问题陈述
[我们在解决什么问题？为什么现在需要做出这个决定？]

### 约束
- [技术约束]
- [时间线约束]
- [资源约束]
- [兼容性需求]

### 需求
- [必须支持 X]
- [必须在 Y 预算内执行]
- [必须与 Z 集成]

## 决策

[所做的具体技术决策，描述足够详细以供他人实施。]

### 架构图
[ASCII 图或此决策创建的架构描述]

### 关键接口
[此决策创建的 API 合同或接口定义]

## 考虑的替代方案

### 替代方案 1：[名称]
- **描述**：[这将如何工作]
- **优点**：[优势]
- **缺点**：[劣势]
- **拒绝原因**：[为什么没有选择这个]

### 替代方案 2：[名称]
- **描述**：[这将如何工作]
- **优点**：[优势]
- **缺点**：[劣势]
- **拒绝原因**：[为什么没有选择这个]

## 后果

### 积极的
- [此决策的良好结果]

### 消极的
- [接受的权衡和成本]

### 风险
- [可能出错的事情]
- [每个风险的缓解措施]

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| [system-name].md | [来自该 GDD 的特定规则、公式或性能约束] | [该决策如何满足它] |

## 性能影响
- **CPU**：[预期影响]
- **内存**：[预期影响]
- **加载时间**：[预期影响]
- **网络**：[预期影响（如适用）]

## 迁移计划
[如果这更改了现有代码，我们如何从现在到达未来？]

## 验证标准
[我们如何知道这个决策是正确的？哪些指标或测试？]

## 相关决策
- [相关 ADR 的链接]
- [相关设计文档的链接]
```

5.5. **引擎专家验证** —— 在保存之前，通过 Task 召唤**主要引擎专家**来验证已草拟的 ADR：
   - 读取 `.claude/docs/technical-preferences.md` 的 `Engine Specialists` 部分以获取主要专家
   - 如果没有配置引擎（`[TO BE CONFIGURED]`），跳过此步骤
   - 召唤 `subagent_type：[primary specialist]`，提供：ADR 的引擎兼容性部分、决策部分、关键接口和引擎参考文档路径。请他们：
     1. 确认提议的方法对锁定的引擎版本是否惯用
     2. 标记任何在训练截止日期后已弃用或更改的 API 或模式
     3. 识别当前 ADR 草案中未包含的引擎特定风险或陷阱
   - 如果专家识别出**阻塞问题**（错误的 API、已弃用的方法、引擎版本不兼容）：相应修改决策和引擎兼容性部分，然后在继续前与用户确认更改
   - 如果专家只发现了**小问题**：将其纳入 ADR 的风险子部分

**审查模式检查** —— 在召唤 TD-ADR 之前应用：
- `solo` → 跳过。注意："TD-ADR 已跳过——Solo 模式。" 继续步骤 5.7（GDD 同步检查）。
- `lean` → 跳过（不是 PHASE-GATE）。注意："TD-ADR 已跳过——Lean 模式。" 继续步骤 5.7（GDD 同步检查）。
- `full` → 正常召唤。

5.6. **技术主管战略审查** —— 在引擎专家验证之后，通过 Task 使用关卡 **TD-ADR** 召唤 `technical-director`（`.claude/docs/director-gates.md`）：
   - 传递：ADR 文件路径（或草案内容）、引擎版本、领域、同一领域的任何现有 ADR
   - 技术主管验证架构连贯性（该决策是否与整个系统一致？）—— 区别于引擎专家的 API 级别检查
   - 如果有关切（CONCERNS）或拒绝（REJECT）：在继续之前相应修改决策或替代方案部分

5.7. **GDD 同步检查** —— 在呈现写入批准之前，扫描"解决的 GDD 需求"部分中引用的所有 GDD，检查名称是否与 ADR 的关键接口和决策部分不一致（重命名的信号、API 方法或数据类型）。如果发现任何不一致，将其作为**突出的警告块**呈现在写入批准之前——而不是作为脚注：

```
⚠️ 需要 GDD 同步
[gdd-filename].md 使用了本 ADR 已重命名的名称：
  [old_name] → [new_name_from_adr]
  [old_name_2] → [new_name_2_from_adr]
GDD 必须在写入此 ADR 之前或同时更新，以防止阅读 GDD 的开发者实现错误的接口。
```

如果没有不一致：静默跳过此块。

5. **写入批准** —— 使用 `AskUserQuestion`：

如果发现 GDD 同步问题：
- "ADR 草案已完成。您想如何继续？"
  - [A] 在同一个操作中写入 ADR 并更新 GDD
  - [B] 仅写入 ADR —— 我会手动更新 GDD
  - [C] 还不——我需要进一步审查

如果没有 GDD 同步问题：
- "ADR 草案已完成。我可以写入吗？"
  - [A] 将 ADR 写入 `docs/architecture/adr-[NNNN]-[slug].md`
  - [B] 还不——我需要进一步审查

如果同意任何写入选项，写入文件，必要时创建目录。对于带有 GDD 更新的选项 [A]：同时更新 GDD 文件以使用新名称。

6. **更新架构注册表**

扫描已写入的 ADR 查找应注册的新架构立场：
- 它主张拥有的状态
- 它定义的接口合同（信号签名、方法 API）
- 它声明的性能预算
- 它明确做出的 API 选择
- 它禁止的模式（后果 → 负面或明确的"不要使用 X"）

呈现候选：
```
此 ADR 的注册表候选：
  新状态所有权：     player_stamina → stamina-system
  新接口合同：   stamina_depleted 信号
  新性能预算：   stamina-system：每帧 0.5ms
  新禁止模式：    每帧轮询 stamina（改用信号）
  现有（仅更新 referenced_by）：player_health → 已注册 ✅
```

**注册表追加逻辑**：在写入 `docs/registry/architecture.yaml` 时，不要假设部分是空的。文件可能已有此会话中先前 ADR 写入的条目。在每次 Edit 调用之前：
1. 读取 `docs/registry/architecture.yaml` 的当前状态
2. 找到正确的部分（state_ownership、interfaces、forbidden_patterns、api_decisions）
3. 在该部分最后一个现有条目之后追加新条目——不要尝试替换可能已不存在的 `[]` 占位符
4. 如果该部分已有条目，使用最后一个条目的结尾内容作为 `old_string` 锚点，并在其后追加新条目

**阻塞（BLOCKING）—— 未经明确的用户批准不得写入 `docs/registry/architecture.yaml`。**

使用 `AskUserQuestion` 询问：
- "我可以使用这些 [N] 个新立场更新 `docs/registry/architecture.yaml` 吗？"
  - 选项："是——更新注册表"、"还不——我想审查候选"、"跳过注册表更新"

仅在用户选择"是"时继续。如果同意：追加新条目。绝不修改现有条目——如果立场发生变化，将旧条目设置为 `status：superseded_by：ADR-[NNNN]` 并添加新条目。

---

## 6. 收尾下一步

在 ADR 写入后（并可选择更新注册表），使用 `AskUserQuestion` 收尾。

在生成 widget 之前：
1. 读取 `docs/registry/architecture.yaml` —— 检查是否有任何优先 ADR 仍未编写（查找在 technical-preferences.md 或 systems-index.md 中标记为先决条件的 ADR）
2. 检查是否所有先决条件 ADR 现已编写。如果是，包含"开始编写 GDD"选项。
3. 列出所有剩余的优先 ADR 作为单独选项——不仅仅是一两个。

Widget 格式：
```
ADR-[NNNN] 已写入且注册表已更新。接下来想做什么？
[1] 编写 [next-priority-adr-name] —— [来自先决条件列表的简要描述]
[2] 编写 [another-priority-adr] —— [简要描述]（包括所有剩余项）
[N] 开始编写 GDD —— 运行 `/design-system [first-undesigned-system]`（仅当所有先决条件 ADR 已编写时显示）
[N+1] 在此会话中暂停
```

如果没有剩余的优先 ADR，也没有未设计的 GDD 系统，仅提供"暂停"，并建议在全新的会话中运行 `/architecture-review`。

**在收尾输出中始终包含此固定通知（不要省略它）：**

> 要验证 ADR 对 GDD 的覆盖范围，打开一个**全新的 Claude Code 会话**并运行 `/architecture-review`。
>
> **绝不在与 `/architecture-decision` 相同的会话中运行 `/architecture-review`。**
> 审查代理必须独立于编写上下文，以提供无偏见的评估。在此处运行会使审查无效。

将任何状态为 `Status：Blocked` 等待此 ADR 的故事更新为 `Status：Ready`。
