
# Agent Test Spec: art-director（美术总监）

## Agent Summary（代理概述）
**Domain owned（所属领域）：** Visual identity, art bible authorship and enforcement, asset quality standards, UI/UX visual design, visual phase gate, concept art evaluation.
视觉形象、美术圣经（Art Bible）撰写与执行、资产质量标准、UI/UX 视觉设计、视觉阶段门禁（Phase Gate）、概念美术评估。
**Does NOT own（不拥有的领域）：** UX interaction flows and information architecture (ux-designer's domain), audio direction (audio-director), code implementation.
UX 交互流程与信息架构（ux-designer 的领域）、音频方向（audio-director）、代码实现。
**Model tier（模型层级）：** Sonnet（注意：尽管头衔为"director"，art-director 根据 coordination-rules.md 被分配为 Sonnet 层级——它处理单系统分析，而非 Opus 级别的多文档阶段门禁综合评审）。
**Gate IDs handled（负责的门禁 ID）：** AD-CONCEPT-VISUAL, AD-ART-BIBLE, AD-PHASE-GATE.

---

## Static Assertions (Structural)（静态断言——结构性）

通过阅读代理的 `.claude/agents/art-director.md` frontmatter 进行验证：

- [ ] `description:` 字段存在且领域特定（提及视觉形象、美术圣经、资产标准——而非泛泛而谈）
- [ ] `allowed-tools:` 列表以读取为主；如有支持则包含图像审查能力；除非资产管线检查有正当理由，否则不包含 Bash
- [ ] 模型层级为 `claude-sonnet-4-6`（非 Opus——coordination-rules.md 将 art-director 分配为 Sonnet）
- [ ] 代理定义未声称对 UX 交互流程或音频方向拥有权威

---

## Test Cases（测试用例）

### Case 1: In-domain request — appropriate output format（领域内请求——合适的输出格式）
**Scenario（场景）：** 提交美术圣经（Art Bible）的调色板部分供审查。该部分定义了一套低饱和度大地色调主调色板，搭配与游戏支柱（Game Pillar）"腐朽之美（beauty in decay）"相关联的高对比度强调色。调色板内部一致，并引用了支柱词汇。请求标记为 AD-ART-BIBLE。
**Expected（预期）：** 返回 `AD-ART-BIBLE: APPROVE`，并附理由确认调色板的内部一致性及其与所述支柱的对齐。
**Assertions（断言）：**
- [ ] 结论严格为 APPROVE / CONCERNS / REJECT 之一
- [ ] 结论标记格式为 `AD-ART-BIBLE: APPROVE`
- [ ] 理由引用具体的调色板特征和支柱对齐——而非泛泛的美术建议
- [ ] 输出保持在视觉领域内——不评论 UX 交互模式或音频氛围

### Case 2: Out-of-domain request — redirects or escalates（领域外请求——重定向或升级）
**Scenario（场景）：** 音效设计师（Sound Designer）要求 art-director 指定当玩家进入战斗区域时，环境音频应如何分层和闪避。
**Expected（预期）：** 代理拒绝定义音频行为，并重定向到 audio-director。
**Assertions（断言）：**
- [ ] 不对音频分层或闪避行为做出任何有约束力的决定
- [ ] 明确指出 `audio-director` 是正确的处理者
- [ ] 可以注明音频的视觉氛围影响（例如"音频应与区域的视觉张力相匹配"），但将所有音频规格制定交由 audio-director 决定

### Case 3: Gate verdict — correct vocabulary（门禁结论——正确的词汇）
**Scenario（场景）：** 提交主角（Protagonist）的概念美术（Concept Art）。该美术使用鲜艳饱和的调色板（主色：#FF4500, #00BFFF），直接违背了已确立的美术圣经中"低饱和度大地色系"的调色板规范。请求标记为 AD-CONCEPT-VISUAL。
**Expected（预期）：** 返回 `AD-CONCEPT-VISUAL: CONCERNS`，并具体引用调色板差异，指出美术圣经规定的调色板值与提交的概念作品所用调色板的对比。
**Assertions（断言）：**
- [ ] 结论严格为 APPROVE / CONCERNS / REJECT 之一——而非自由文本
- [ ] 结论标记格式为 `AD-CONCEPT-VISUAL: CONCERNS`
- [ ] 理由明确指认调色板冲突——而非泛泛的"风格不符"评论
- [ ] 引用美术圣经作为正确调色板的权威来源

### Case 4: Conflict escalation — correct parent（冲突升级——正确的上级）
**Scenario（场景）：** ux-designer 提议使用高对比度、色彩鲜明的图标提升 HUD 可读性。art-director 认为这违反了美术圣经的柔和视觉语言，会损害视觉形象。
**Expected（预期）：** art-director 陈述视觉形象方面的顾虑并引用美术圣经，承认 ux-designer 的可读性目标是合理的，并将此升级至 creative-director 以仲裁视觉一致性与可用性之间的权衡。
**Assertions（断言）：**
- [ ] 升级至 `creative-director`（创意领域冲突的共享上级）
- [ ] 不单方面推翻 ux-designer 的可读性建议
- [ ] 明确将冲突框定为两个合理目标之间的权衡
- [ ] 引用被违反的具体美术圣经规则

### Case 5: Context pass — uses provided context（上下文传递——使用提供的上下文）
**Scenario（场景）：** 代理收到一个门禁上下文块，其中包含现有美术圣经的具体调色板值（主色：#8B7355, #6B6B47；强调色：#C8A96E）和风格规则（"无纯白，无纯黑；所有阴影带有暖色调"）。提交了一个新资产供审查。
**Expected（预期）：** 评估引用所提供美术圣经中的具体十六进制颜色值和风格规则，而非泛泛的色彩理论建议。任何顾虑都需与所提供规则的具体违反行为关联。
**Assertions（断言）：**
- [ ] 引用所提供美术圣经上下文中的具体调色板值
- [ ] 应用所提供文档中的具体风格规则（无纯白/纯黑，暖色阴影调）
- [ ] 不生成与所提供美术圣经脱节的一般性美术方向反馈
- [ ] 结论理由可追溯至所提供上下文中的具体行或规则

---

## Protocol Compliance（协议合规）

- [ ] 仅使用 APPROVE / CONCERNS / REJECT 词汇返回结论
- [ ] 保持在声明的视觉领域内
- [ ] UX 与视觉冲突升级至 creative-director
- [ ] 在输出中使用门禁 ID（例如 `AD-ART-BIBLE: APPROVE`），而非行内散文式结论
- [ ] 不做出有约束力的 UX 交互、音频或代码实现决定

---

## Coverage Notes（覆盖说明）
- AD-PHASE-GATE（完整视觉阶段推进）未覆盖——推迟到与 /gate-check 技能集成。
- 资产管线标准（文件格式、分辨率、命名规范）合规性检查未覆盖。
- 着色器（Shader）视觉输出审查未覆盖——推迟到与引擎专家的交互。
- UI 组件视觉审查（区别于 UX 流程审查）可从增加额外用例中受益。
