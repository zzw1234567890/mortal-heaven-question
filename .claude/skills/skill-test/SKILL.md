---
name: skill-test
description: "验证技能文件的结构合规性和行为正确性。三种模式：static（linter）、spec（行为验证）、audit（覆盖率报告）。"
argument-hint: "static [skill-name | all] | spec [skill-name] | category [skill-name | all] | audit"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write

---


# 技能测试

验证 `.claude/skills/*/SKILL.md` 文件的结构合规性和行为正确性。无外部依赖——完全在现有的技能/钩子/模板架构内运行。

**四种模式：**

| 模式 | 命令 | 目的 | Token 成本 |
|------|---------|---------|------------|
| `static` | `/skill-test static [name\|all]` | 结构检查器——每个技能 7 项合规检查 | 低（约 1k/技能） |
| `spec` | `/skill-test spec [name]` | 行为验证器——评估测试规范中的断言 | 中（约 5k/技能） |
| `category` | `/skill-test category [name\|all]` | 类别评分标准——检查技能是否符合其类别特定指标 | 低（约 2k/技能） |
| `audit` | `/skill-test audit` | 覆盖率报告——技能、代理规范、最后测试日期 | 低（总计约 3k） |

---

## 阶段 1：解析参数

从第一个参数确定模式：

- `static [name]` → 对一个技能运行 7 项结构检查
- `static all` → 对所有技能运行 7 项结构检查（Glob `.claude/skills/*/SKILL.md`）
- `spec [name]` → 读取技能 + 测试规范，评估断言
- `category [name]` → 从 `CCGS Skill Testing Framework/quality-rubric.md` 运行类别特定评分标准
- `category all` → 为 catalog 中具有 `category:` 的每个技能运行类别评分标准
- `audit`（或无参数） → 读取 catalog，列出所有技能和代理，显示覆盖率

如果参数缺失或无法识别，输出用法并停止。

---

## 阶段 2A：静态模式 — 结构检查器

对于每个被测试的技能，完整读取其 `SKILL.md` 并运行所有 7 项检查：

### 检查 1 — 必需的 frontmatter 字段
文件必须在 YAML frontmatter 块中包含所有这些字段：
- `name:`
- `description:`
- `argument-hint:`
- `user-invocable:`
- `allowed-tools:`

**FAIL** 如果任何一项缺失。

### 检查 2 — 多个阶段
技能必须包含 ≥2 个编号的阶段标题。查找以下模式：
- `## Phase N` 或 `## Phase N:`
- `## N.`（编号的顶级章节）
- 如果阶段没有明确编号，至少 2 个不同的 `##` 标题

**FAIL** 如果找到少于 2 个类似阶段的标题。

### 检查 3 — 裁决关键字
技能必须包含至少一个：`PASS`、`FAIL`、`CONCERNS`、`APPROVED`、`BLOCKED`、`COMPLETE`、`READY`、`COMPLIANT`、`NON-COMPLIANT`

**FAIL** 如果没有任何一个出现。

### 检查 4 — 协作协议语言
技能必须包含先问再写的语言。查找：
- `"May I write"`（标准形式）
- `"before writing"` 或 `"approval"` 靠近文件写入指令
- `"ask"` + `"write"` 在相近的位置（同一部分内）

**WARN** 如果不存在（某些只读技能合法地跳过此项）。
**FAIL** 如果 `allowed-tools` 包含 `Write` 或 `Edit` 但未找到先问再写的语言。

### 检查 5 — 下一步交接
技能必须以推荐的下一步操作或后续路径结束。查找：
- 提及另一个技能的最终部分（例如 `/story-done`、`/gate-check`）
- "Recommended next" 或 "next step" 措辞
- "Follow-Up" 或 "After this" 部分

**WARN** 如果不存在。

### 检查 6 — Fork 上下文复杂性
如果 frontmatter 包含 `context: fork`，技能应有 ≥5 个阶段标题（`##` 级别或编号的 Phase N 标题）。Fork 上下文适用于复杂的多阶段技能；简单技能不应使用它。

**WARN** 如果设置了 `context: fork` 但找到的阶段少于 5 个。

### 检查 7 — 参数提示合理性
`argument-hint` 必须非空。如果技能正文提到多种模式（例如"模式 A | 模式 B"），提示应反映这些模式。将提示与第一个阶段的"解析参数"部分交叉引用。

**WARN** 如果提示为 `""` 或文档中的模式与提示不匹配。

---

### 静态模式输出格式

对于单个技能：
```
=== 技能静态检查：/[name] ===

检查 1 — Frontmatter 字段：    PASS
检查 2 — 多个阶段：           PASS（找到 7 个阶段）
检查 3 — 裁决关键字：         PASS（PASS、FAIL、CONCERNS）
检查 4 — 协作协议：           PASS（找到"May I write"）
检查 5 — 下一步交接：         WARN（未找到后续部分）
检查 6 — Fork 上下文复杂性：  PASS（8 个阶段，context: fork 已设置）
检查 7 — 参数提示：           PASS

裁决：警告（1 个警告，0 个失败）
建议：在技能末尾添加"后续操作"部分。
```

对于 `static all`，生成摘要表然后列出任何不合规的技能：
```
=== 技能静态检查：全部 52 个技能 ===

技能                  | 结果          | 问题
-----------------------|--------------|-------
gate-check             | 合规         |
design-review          | 合规         |
story-readiness        | 警告         | 检查 5：无交接
...

摘要：48 个合规，3 个警告，1 个不合规
汇总裁决：N 个警告 / N 个失败
```

---

## 阶段 2B：Spec 模式 — 行为验证器

### 步骤 1 — 定位文件

在 `.claude/skills/[name]/SKILL.md` 找到技能。
从 `CCGS Skill Testing Framework/catalog.yaml` 查找规范路径 — 使用匹配技能条目的 `spec:` 字段。

如果两者之一缺失：
- 技能缺失："未在 `.claude/skills/` 中找到技能 '[name]'。"
- catalog 中无规范路径："在 catalog.yaml 中未为 '[name]' 设置规范路径。"
- 路径处未找到规范文件："规范文件在 [path] 缺失。运行 `/skill-test audit` 查看覆盖率缺口。"

### 步骤 2 — 读取两个文件

完整读取技能文件和测试规范文件。

### 步骤 3 — 评估断言

对于规范中的每个**测试用例**：

1. 读取**固件**描述（项目文件的假定状态）
2. 读取**预期行为**步骤
3. 读取每个**断言**复选框

对于每个断言，评估如果技能根据固件状态正确执行其书面指令，是否能满足断言。这是由 Claude 评估的推理检查，而非代码执行。

标记每个断言：
- **PASS** — 技能指令明确满足此断言
- **PARTIAL** — 技能指令部分满足，但存在歧义
- **FAIL** — 在给定固件的条件下，技能指令不会满足此断言

对于**协议合规性**断言（始终存在）：
- 检查技能是否要求在文件写入前使用"May I write"
- 检查技能是否在请求批准前呈现发现
- 检查技能是否以推荐的下一步结束
- 检查技能是否避免未经批准自动创建文件

### 步骤 4 — 构建报告

```
=== 技能 Spec 测试：/[name] ===
日期：[date]
规范：CCGS Skill Testing Framework/skills/[category]/[name].md

用例 1：[快乐路径 — 名称]
  固件：[摘要]
  断言：
    [PASS] [断言文本]
    [FAIL] [断言文本]
       原因：技能的阶段 3 说"..."但固件状态意味着"..."
  用例裁决：FAIL

用例 2：[边界情况 — 名称]
  ...
  用例裁决：PASS

协议合规性：
  [PASS] 在文件写入前使用"May I write"
  [PASS] 在请求批准前呈现发现
  [WARN] 末尾没有显式的下一步交接

总体裁决：FAIL（1 个用例失败，1 个警告）
```

### 步骤 5 — 提供写入结果

"我可以将这些结果写入 `CCGS Skill Testing Framework/results/skill-test-spec-[name]-[date].md` 并更新 `CCGS Skill Testing Framework/catalog.yaml` 吗？"

如果同意：
- 将结果文件写入 `CCGS Skill Testing Framework/results/`
- 更新 `CCGS Skill Testing Framework/catalog.yaml` 中技能的条目：
  - `last_spec: [date]`
  - `last_spec_result: PASS|PARTIAL|FAIL`

---

## 阶段 2D：Category 模式 — 评分标准评估

### 步骤 1 — 定位技能和类别

在 `.claude/skills/[name]/SKILL.md` 找到技能。
在 `CCGS Skill Testing Framework/catalog.yaml` 中查找 `category:` 字段。

如果未找到技能："未找到技能 '[name]'。"
如果无 `category:` 字段："在 catalog.yaml 中未为 '[name]' 分配类别。首先添加 `category: [name]` 到技能条目。"

对于 `category all`：收集所有具有 `category:` 字段的技能并处理每个。
`category: utility` 技能仅评估 U1（静态检查通过）和 U2（门禁模式正确，如适用）——跳到 U1 的静态模式。

### 步骤 2 — 读取评分标准部分

读取 `CCGS Skill Testing Framework/quality-rubric.md`。
提取与技能类别匹配的部分（例如 `### gate`、`### team`）。

### 步骤 3 — 读取技能

完整读取技能的 `SKILL.md`。

### 步骤 4 — 评估评分标准指标

对于类别评分标准表中的每个指标：
1. 检查技能的书面指令是否明确满足标准
2. 标记 PASS、FAIL 或 WARN
3. 对于 FAIL/WARN，在技能文本中确定确切差距（引用相关部分或注明其缺失）

### 步骤 5 — 输出报告

```
=== 技能类别检查：/[name]（[category]）===

指标 G1 — 审查模式读取：      PASS
指标 G2 — 完整模式主管：       FAIL
  差距：阶段 3 仅生成了 CD-PHASE-GATE；TD-PHASE-GATE、PR-PHASE-GATE、AD-PHASE-GATE 缺失
指标 G3 — 精简模式：仅 PHASE-GATE：PASS
指标 G4 — 独奏模式：无主管：  PASS
指标 G5 — 不自动推进：       PASS

裁决：FAIL（1 个失败，0 个警告）
修复：将 TD-PHASE-GATE、PR-PHASE-GATE 和 AD-PHASE-GATE 添加到阶段 3 的完整模式主管面板中。
```

### 步骤 6 — 提供更新 Catalog

"我可以更新 `CCGS Skill Testing Framework/catalog.yaml` 来记录此次类别检查（`last_category`、`last_category_result`）为 [name] 吗？"

---

## 阶段 2C：Audit 模式 — 覆盖率报告

### 步骤 1 — 读取 Catalog

读取 `CCGS Skill Testing Framework/catalog.yaml`。如果缺失，注明 catalog 尚不存在（首次运行状态）。

### 步骤 2 — 枚举所有技能和代理

Glob `.claude/skills/*/SKILL.md` 以获取完整的技能列表。
从每个路径（目录名）提取技能名称。

同时从 `CCGS Skill Testing Framework/catalog.yaml` 的 `agents:` 部分获取完整的代理列表。

### 步骤 3 — 构建技能覆盖率表

对于每个技能：
- 检查规范文件是否存在（使用 catalog 中的 `spec:` 路径，或 glob `CCGS Skill Testing Framework/skills/*/[name].md`）
- 从 catalog 中查找 `last_static`、`last_static_result`、`last_spec`、`last_spec_result`、`last_category`、`last_category_result`、`category`（如果不在 catalog 中则标记为"never"或"—"）
- 优先级来自 catalog 的 `priority:` 字段（critical/high/medium/low）

### 步骤 3b — 构建代理覆盖率表

对于 catalog 的 `agents:` 部分中的每个代理：
- 检查规范文件是否存在（使用 catalog 中的 `spec:` 路径，或 glob `CCGS Skill Testing Framework/agents/*/[name].md`）
- 从 catalog 中查找 `last_spec`、`last_spec_result`、`category`

### 步骤 4 — 输出报告

```
=== 技能测试覆盖率审计 ===
日期：[date]

技能（共 72 个）
已编写规范：72 个（100%）| 从未静态测试：72 个 | 从未类别测试：72 个

技能                  | 类别      | 有规范 | 最后静态 | S.结果 | 最后类别 | C.结果 | 优先级
-----------------------|----------|----------|-------------|----------|----------|----------|----------
gate-check             | gate     | 是       | never       | —        | never    | —        | critical
design-review          | review   | 是       | never       | —        | never    | —        | critical
...

代理（共 49 个）
已编写代理规范：49 个（100%）

代理                  | 类别       | 有规范 | 最后规范   | 结果
-----------------------|------------|----------|-------------|--------
creative-director      | director   | 是       | never       | —
technical-director     | director   | 是       | never       | —
...

前 5 个优先级缺口（无规范的技能，critical/high 优先级）：
（如果所有规范均已编写则为空）

技能覆盖率： 72/72 个规范（100%）
代理覆盖率： 49/49 个规范（100%）
```

审计模式下不写入文件。

提供："您是否想运行 `/skill-test static all` 检查所有技能的结构合规性？`/skill-test category all` 运行类别评分标准检查？或者 `/skill-test spec [name]` 运行特定的行为测试？"

---

## 阶段 3：推荐的后续步骤

在任何模式完成后，提供上下文相关后续操作：

- 在 `static [name]` 之后："如果存在测试规范，运行 `/skill-test spec [name]` 验证行为正确性。"
- 在带有失败的 `static all` 之后："首先处理不合规的技能。单独运行 `/skill-test static [name]` 以获取详细的修复指导。"
- 在 `spec [name]` 通过之后："更新 `CCGS Skill Testing Framework/catalog.yaml` 以记录此次通过日期。考虑运行 `/skill-test audit` 以查找下一个规范缺口。"
- 在 `spec [name]` 失败之后："审查失败的断言并更新技能或测试规范以解决不匹配。"
- 在 `audit` 之后："从关键优先级差距开始。使用 `CCGS Skill Testing Framework/templates/skill-test-spec.md` 的规范模板创建新规范。"
