---
name: localize
description: "完整本地化管线：扫描硬编码字符串、提取和管理字符串表、验证翻译、生成翻译摘要、运行文化/敏感性审查、管理配音本地化、测试RTL/平台要求、强制执行字符串冻结并报告覆盖率。"
argument-hint: "[scan|extract|validate|status|brief|cultural-review|vo-pipeline|rtl-check|freeze|qa]"
user-invocable: true
agent: localization-lead
allowed-tools: Read, Glob, Grep, Write, Bash, Task, AskUserQuestion

---


# 本地化管线 (Localization Pipeline)

本地化不仅仅是翻译 —— 它是让游戏在每个语言和地区都感觉像原生游戏一样的完整过程。糟糕的本地化会破坏沉浸感、困惑玩家，并阻碍平台认证。此技能涵盖从字符串提取到文化审查、VO 录音、RTL 布局测试以及本地化质量保证签收的完整管线。

**模式 (Modes):**
- `scan` — 查找硬编码字符串和本地化反模式（只读）
- `extract` — 提取字符串并生成翻译就绪表
- `validate` — 检查翻译的完整性、占位符和长度
- `status` — 所有语言环境的覆盖率矩阵
- `brief` — 为外部团队生成翻译人员上下文简报文档
- `cultural-review` — 标记文化敏感内容、符号、颜色、习语
- `vo-pipeline` — 管理配音本地化：脚本、录音规范、集成
- `rtl-check` — 验证 RTL 语言布局、镜像和字体支持
- `freeze` — 强制字符串冻结；在翻译开始前锁定源字符串
- `qa` — 在发布前运行完整的本地化质量保证周期

如果未提供子命令，则输出用法并停止。裁定：**FAIL** —— 缺少必需的子命令。

---

## 阶段 2A：扫描模式 (Scan Mode)

搜索 `src/` 中硬编码的面向用户的字符串：

- 未包装在本地化函数（`tr()`、`Tr()`、`NSLocalizedString`、`GetText` 等）中的 UI 代码字符串字面量
- 本应参数化的拼接字符串
- 使用位置占位符（`%s`、`%d`）而非命名占位符（`{playerName}`）的字符串
- 混合了区域敏感数据（数字、日期、货币）但未使用区域感知格式的格式字符串

搜索本地化反模式：

- 未使用区域感知函数的日期/时间格式化
- 无区域感知的数字格式化（`1,000` vs `1.000`）
- 嵌入图像或纹理中的文本（标记 `assets/` 中的资源文件）
- 假定从左到右文本方向的字符串（位置布局、字符串组装顺序）
- 字符串逻辑中硬编码的性别/复数假设（必须使用复数形式或性别标记）
- 硬编码的标点符号（例如 `"You won!"` —— 感叹风格因区域而异）

报告所有发现，包括文件路径和行号。此模式为只读 —— 不写入文件。

---

## 阶段 2B：提取模式 (Extract Mode)

- 扫描所有源文件中已本地化的字符串引用
- 与 `assets/data/strings/` 中现有的字符串表进行比较
- 为尚未键化的字符串生成新条目
- 建议遵循约定的键名：`[category].[subcategory].[description]`
  - 示例：`ui.hud.health_label`、`dialogue.npc.merchant.greeting`、`menu.main.play_button`
- 每个新条目必须包含一个 `context` 字段 —— 一条翻译人员注释，说明：
  - 它出现在哪里（哪个屏幕、哪个场景）
  - 最大字符长度
  - 任何占位符含义（`{playerName}` = 玩家选择的显示名称）
  - 性别/复数上下文（如适用）

输出要添加到字符串表中的新字符串的差异。

向用户展示差异。询问："我可以将这些新条目写入 `assets/data/strings/strings-en.json` 吗？"

如果是，仅写入差异（新条目），而非完整替换。裁定：**COMPLETE** —— 字符串已提取并写入。

---

## 阶段 2C：验证模式 (Validate Mode)

读取 `assets/data/strings/` 中的所有字符串表文件。对于每个语言环境，检查：

- **完整性** —— 键存在于源 (en) 中但该语言环境没有翻译
- **占位符不匹配** —— 源有 `{name}` 但翻译省略了它或添加了额外的
- **字符串长度违规** —— 翻译超过源 `context` 字段中记录的字符限制
- **复数形式数量** —— 语言环境需要 N 种复数形式；翻译提供的较少
- **孤立键** —— 翻译存在但 `src/` 中没有引用该键
- **过期翻译** —— 翻译写入后源字符串已更改（标记为需重新翻译）
- **编码** —— 存在非 ASCII 字符且字体图集支持它们（如果不确定则标记）

按语言环境和严重程度分组报告验证结果。此模式为只读 —— 不写入文件。

---

## 阶段 2D：状态模式 (Status Mode)

- 统计源表中的可本地化字符串总数
- 按语言环境：统计已翻译、未翻译、过期（翻译后源已更改）的数量
- 生成覆盖率矩阵：

```markdown
## Localization Status
Generated: [Date]
String freeze: [Active / Not yet called / Lifted]

| Locale | Total | Translated | Missing | Stale | Coverage |
|--------|-------|-----------|---------|-------|----------|
| en (source) | [N] | [N] | 0 | 0 | 100% |
| [locale] | [N] | [N] | [N] | [N] | [X]% |

### Issues
- [N] hardcoded strings found in source code (run /localize scan)
- [N] strings exceeding character limits
- [N] placeholder mismatches
- [N] orphaned keys
- [N] strings added after freeze was called (freeze violations)
```

此模式为只读 —— 不写入文件。

---

## 阶段 2E：简报模式 (Brief Mode)

生成翻译人员上下文简报文档。此文档随字符串表导出一起发送给外部翻译团队或本地化供应商。

读取：
- `design/gdd/` — 提取游戏类型、基调、设定、角色名称
- `assets/data/strings/strings-en.json` — 源字符串表
- `design/narrative/` 中任何现有的世界观或叙事文档

生成 `production/localization/translator-brief-[locale]-[date].md`：

```markdown
# Translator Brief — [Game Name] — [Locale]

## Game Overview
[2-3 paragraph summary of the game, genre, tone, and audience]

## Tone and Voice
- **Overall tone**: [e.g., "Darkly comic, not slapstick — think Terry Pratchett, not Looney Tunes"]
- **Player address**: [e.g., "Second person, informal. Never formal 'vous' — always 'tu' for French"]
- **Profanity policy**: [e.g., "Mild — PG-13 equivalent. Match intensity to source, do not soften or escalate"]
- **Humour**: [e.g., "Wordplay exists — if a pun cannot translate, invent an equivalent local joke; do not translate literally"]

## Character Glossary
| Name | Role | Personality | Notes |
|------|------|-------------|-------|
| [Name] | [Role] | [Personality] | [Do not translate / transliterate as X] |

## World Glossary
| Term | Meaning | Notes |
|------|---------|-------|
| [Term] | [What it means] | [Keep in English / translate as X] |

## Do Not Translate List
The following must appear verbatim in all locales:
- [Game name]
- [UI terms that match in-engine labels]
- [Brand or trademark names]

## Placeholder Reference
| Placeholder | What it represents | Example |
|-------------|-------------------|---------|
| `{playerName}` | Player's chosen display name | "Shadowblade" |
| `{count}` | Integer quantity | "3" |

## Character Limits
Tight UI fields with hard limits are marked in the string table `context` field.
Where no limit is stated, target ±30% of the English length as a guideline.

## Contact
Direct questions to: [placeholder for user/team contact]
Delivery format: JSON, same schema as strings-en.json
```

询问："我可以将此翻译人员简报写入 `production/localization/translator-brief-[locale]-[date].md` 吗？"

---

## 阶段 2F：文化审查模式 (Cultural Review Mode)

通过 Task 生成 `localization-lead`。要求他们针对目标语言环境（从 `assets/data/strings/` 和 `assets/` 中读取）审计以下内容的文化敏感性：

### 需审查的内容领域

**符号和手势**
- 竖大拇指、OK 手势、和平手势 —— 含义因地区而异
- 美术、UI 或音频中的宗教或精神符号
- 国旗、地图表示、争议领土

**颜色**
- 白色（一些亚洲文化中的丧事）、绿色（某些地区的政治关联）、红色（好运 vs 危险）
- 与文化关联冲突的警报/警告颜色

**数字**
- 4（日语/汉语中的"死"）、13、666 —— 在 UI 中标记使用（房间号、物品数量、价格）

**幽默和习语**
- 在其他语言环境中翻译为冒犯性内容的习语
- 在某些市场（特别是日本、德国、中东）不适宜的厕所/身体幽默
- 围绕特定地区文化敏感话题的黑色幽默

**暴力和内容分级**
- 在 DE（德国）、AU（澳大利亚）、CN（中国）或 AE（阿联酋）需要更改分级的内容
- 血色、血腥程度、毒品引用 —— 如有需要，标记所有内容以生成地区特定资源变体

**名称和表现**
- 在目标语言环境中具有冒犯性、亵渎性或负面含义的角色名称
- 对国家、宗教或民族的刻板印象表现

以表格形式呈现发现：

| Finding | Locale(s) Affected | Severity | Recommended Action |
|---------|--------------------|----------|--------------------|
| [Description] | [Locale] | [BLOCKING / ADVISORY / NOTE] | [Change / Flag for review / Accept] |

BLOCKING = 在发布该语言环境之前必须修复。ADVISORY = 建议更改。NOTE = 仅供参考。

询问："我可以将此文化审查报告写入 `production/localization/cultural-review-[date].md` 吗？"

---

## 阶段 2G：VO 管线模式 (VO Pipeline Mode)

管理配音本地化过程。根据参数确定子任务：

- `vo-pipeline scan` — 识别所有需要 VO 录音的对白行
- `vo-pipeline script` — 生成带有导演注释的录音脚本
- `vo-pipeline validate` — 检查所有录制的 VO 文件是否存在且命名正确
- `vo-pipeline integrate` — 验证 VO 文件在代码/资源中是否正确引用

### VO 管线：扫描 (Scan)

读取 `assets/data/strings/` 和 `design/narrative/`。识别：
- 所有对白行（键匹配 `dialogue.*`）及其源文本
- 已录制的行（音频文件存在于 `assets/audio/vo/`）
- 尚未录制的行

输出录音清单：

```
## VO Recording Manifest — [Date]

| Key | Character | Source Line | Status |
|-----|-----------|-------------|--------|
| dialogue.npc.merchant.greeting | Merchant | "Welcome, traveller." | Recorded |
| dialogue.npc.merchant.haggle | Merchant | "That's my final offer." | Needs recording |
```

### VO 管线：脚本 (Script)

为每个角色生成录音脚本文档，按场景分组。包括：

- 角色名称及简要性格说明
- 完整的对白行，附不常见专有名词的发音指南
- 每行对白的情感/指导说明（`[Warm, welcoming]`、`[Annoyed, clipped]`）
- 对话中作为回应的行（提供上下文："玩家刚刚说了 X"）

询问："我可以将 VO 录音脚本写入 `production/localization/vo-scripts-[locale]-[date].md` 吗？"

### VO 管线：验证 (Validate)

Glob 搜索 `assets/audio/vo/[locale]/` 中的所有 `.wav`/`.ogg` 文件。与 VO 清单交叉引用。报告：
- 缺少的文件（脚本中有行，但无音频文件）
- 多余的文件（音频文件存在，但没有匹配的字符串键）
- 命名约定违规

### VO 管线：集成 (Integrate)

Grep 搜索 `src/` 中的 VO 音频引用。验证每个引用的路径是否存在于 `assets/audio/vo/[locale]/` 中。报告损坏的引用。

---

## 阶段 2H：RTL 检查模式 (RTL Check Mode)

从右到左的语言（阿拉伯语、希伯来语、波斯语、乌尔都语）需要超越简单文本翻译的布局镜像。此模式验证实现。

读取 `.claude/docs/technical-preferences.md` 以确定引擎。然后检查：

**布局镜像**
- 引擎中是否启用了 RTL 布局？（Godot：`Control.layout_direction`、Unity：`RTL Support` 包、Unreal：文本方向标志）
- 所有 UI 容器是否设置为自动镜像，还是位置是硬编码的？
- 进度条、生命条和方向指示器是否正确镜像？

**文本渲染**
- 是否加载了支持阿拉伯语/希伯来语字符集的字体？
- 阿拉伯语文本是否以正确的连字形式渲染（连接脚本）？
- 数字是否在需要时显示为东阿拉伯数字？

**字符串组装**
- 是否存在假定从左到右阅读顺序的字符串拼接？
- 当句子结构反转时，`{placeholder}` 在句子中的位置是否正确工作？

**资源审查**
- 是否存在需要镜像变体的带有方向箭头或不对称设计的 UI 图标？
- 是否存在需要 RTL 版本的文本中图像资源？

要检查的 Grep 模式：
- 场景/预制体文件中引擎特定的 RTL 标志
- 任何 `HBoxContainer`、`LinearLayout`、`HorizontalBox` 节点 —— 验证 layout_direction 设置
- 对白或 UI 代码附近使用 `+` 的字符串拼接

报告发现。标记 BLOCKING 问题（不修复内容无法阅读）与 ADVISORY（外观改进）。

询问："我可以将此 RTL 检查报告写入 `production/localization/rtl-check-[date].md` 吗？"

---

## 阶段 2I：冻结模式 (Freeze Mode)

字符串冻结锁定源（英语）字符串表，以便翻译可以在源不在翻译人员眼皮底下变化的情况下进行。

### freeze 调用

检查 `production/localization/freeze-status.md` 中的当前冻结状态（如果存在）。

如果已冻结：
> "字符串冻结当前为 ACTIVE（于 [date] 调用）。自冻结以来已添加或修改了 [N] 个字符串。这些是冻结违规 —— 它们需要重新翻译或获得批准的冻结解除。"

如果未冻结，呈现冻结前检查清单：

```
Pre-Freeze Checklist
[ ] All planned UI screens are implemented
[ ] All dialogue lines are final (no further narrative revisions planned)
[ ] All system strings (error messages, tutorial text) are complete
[ ] /localize scan shows zero hardcoded strings
[ ] /localize validate shows no placeholder mismatches in source (en)
[ ] Marketing strings (store description, achievements) are final
```

使用 `AskUserQuestion`：
- 提示："以上所有项目都已确认吗？调用字符串冻结将锁定源表。"
- 选项：`[A] Yes — call string freeze now` / `[B] No — I still have strings to add`

如果 [A]：写入 `production/localization/freeze-status.md`：

```markdown
# String Freeze Status

**Status**: ACTIVE
**Called**: [date]
**Called by**: [user]
**Total strings at freeze**: [N]

## Post-Freeze Changes
[Any strings added or modified after freeze are listed here automatically by /localize extract]
```

### freeze lift（冻结解除）

如果参数包含 `lift`：将 `freeze-status.md` 的 Status 更新为 `LIFTED`，记录原因和日期。警告："解除冻结需要重新翻译所有已修改的字符串。通知翻译团队。"

### freeze check（冻结检查，集成到 extract）

当 `extract` 模式发现新的或修改后的字符串，且 `freeze-status.md` 显示 Status: ACTIVE 时 —— 将新键追加到 `## Post-Freeze Changes` 并警告：
> "字符串冻结已激活。已添加 [N] 个新/修改的字符串。这些是冻结违规。在继续之前通知您的本地化供应商。"

---

## 阶段 2J：QA 模式 (QA Mode)

本地化质量保证是一个专门的环节，在翻译交付之后但在任何语言环境发布之前运行。这与 `/validate`（检查完整性）不同 —— 这是一个结构化的基于试玩的质量检查。

通过 Task 生成 `localization-lead`，附带：
- 要 QA 的目标语言环境
- 游戏中所有屏幕/流程的列表（来自 `design/gdd/` 或 `/content-audit` 输出）
- 当前的 `/localize validate` 报告
- 文化审查报告（如果存在）

要求 localization-lead 生成涵盖以下内容的 QA 计划：

1. **功能性字符串检查** —— 每个字符串在游戏中显示时没有截断、占位符错误或编码损坏
2. **UI 溢出检查** —— 超过 UI 边界的翻译字符串（即使字符限制内，某些语言也会扩展）
3. **上下文准确性** —— 在游戏中审查 10% 的字符串样本，检查翻译准确性和自然措辞
4. **文化审查项目** —— 验证文化审查中的所有 BLOCKING 项目已解决
5. **VO 同步检查** —— 如果存在 VO，验证翻译后的口型同步或字幕时机可接受
6. **平台认证要求** —— 检查特定平台的本地化要求（年龄分级文本、法律声明、ESRB/PEGI/CERO 文本）

为每个语言环境输出 QA 裁定：

```
## Localization QA Verdict — [Locale]

**Status**: PASS / PASS WITH CONDITIONS / FAIL
**Reviewed by**: localization-lead
**Date**: [date]

### Findings
| ID | Area | Description | Severity | Status |
|----|------|-------------|----------|--------|
| LOC-001 | UI Overflow | "Settings" button text overflows on [Screen] | BLOCKING | Open |
| LOC-002 | Translation | [Key] translation is literal — sounds unnatural | ADVISORY | Open |

### Conditions (if PASS WITH CONDITIONS)
- [Condition 1 — must resolve before ship]

### Sign-Off
[ ] All BLOCKING findings resolved
[ ] Producer approves shipping [Locale]
```

询问："我可以将此本地化 QA 报告写入 `production/localization/loc-qa-[locale]-[date].md` 吗？"

**关卡集成**：Polish 到 Release 的关卡要求每个要发布的语言环境都获得 PASS 或 PASS WITH CONDITIONS 裁定。FAIL 仅阻止该语言环境的发布 —— 其他语言环境如果 QA 通过仍可继续。

---

## 阶段 3：规则和后续步骤 (Rules and Next Steps)

### 规则
- 英语 (en) 始终是源语言环境
- 每个字符串表条目必须包含带有翻译人员注释、字符限制和占位符含义的 `context` 字段
- 绝不直接修改翻译文件 —— 生成差异以供审查
- 字符限制必须按每个 UI 元素定义，并在 validate 模式中强制执行
- 在将字符串发送给翻译人员之前必须调用字符串冻结 —— 绝不翻译移动的目标
- RTL 支持必须从一开始就设计 —— 改造 RTL 布局成本高昂
- 对于任何游戏将在其中进行商业销售的语言环境，文化审查是必需的
- VO 脚本必须包含导演注释 —— 原始对白行会产生平淡的录音

### 推荐工作流

```
/localize scan            → find hardcoded strings
/localize extract         → build string table
/localize freeze          → lock source before sending to translators
/localize brief           → generate translator briefing document
[Send to translators]
/localize validate        → check returned translations
/localize cultural-review → flag culturally sensitive content
/localize rtl-check       → if shipping Arabic / Hebrew / Persian
/localize vo-pipeline     → if shipping dubbed VO
/localize qa              → full localization QA pass
```

当 `qa` 为所有要发布的语言环境返回 PASS 后，在运行 `/gate-check release` 时包含 QA 报告路径。
