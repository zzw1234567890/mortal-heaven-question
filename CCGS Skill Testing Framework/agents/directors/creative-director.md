
# Agent Test Spec: creative-director（创意总监）

## Agent Summary（代理概述）
**Domain owned（所属领域）：** Creative vision, game pillars, GDD alignment, systems decomposition feedback, narrative direction, playtest feedback interpretation, phase gate (creative aspect).
创意愿景、游戏支柱（Game Pillars）、GDD 对齐、系统拆解反馈、叙事方向、玩法测试反馈解读、阶段门禁（Phase Gate，创意方面）。
**Does NOT own（不拥有的领域）：** Technical architecture or implementation details (delegates to technical-director), production scheduling (producer), visual art style execution (delegates to art-director).
技术架构或实现细节（委托给 technical-director）、生产排期（producer）、视觉美术风格执行（委托给 art-director）。
**Model tier（模型层级）：** Opus（多文档综合评审，高风险的阶段门禁裁定）。
**Gate IDs handled（负责的门禁 ID）：** CD-PILLARS, CD-GDD-ALIGN, CD-SYSTEMS, CD-NARRATIVE, CD-PLAYTEST, CD-PHASE-GATE.

---

## Static Assertions (Structural)（静态断言——结构性）

通过阅读代理的 `.claude/agents/creative-director.md` frontmatter 进行验证：

- [ ] `description:` 字段存在且领域特定（提及创意愿景、支柱、GDD 对齐——而非泛泛而谈）
- [ ] `allowed-tools:` 列表以读取为主；除非创意工作流有正当理由，否则不应包含 Bash
- [ ] 模型层级为 `claude-opus-4-6`（依据 coordination-rules.md：具有门禁综合评审职能的总监为 Opus）
- [ ] 代理定义未声称对技术架构或生产排期拥有权威

---

## Test Cases（测试用例）

### Case 1: In-domain request — appropriate output format（领域内请求——合适的输出格式）
**Scenario（场景）：** 提交一份游戏概念文档进行支柱审查。该概念描述了一款以三大支柱为核心的叙事生存游戏："涌现故事（emergent stories）"、"有意义的牺牲（meaningful sacrifice）"和"鲜活的世��（lived-in world）"。请求标记为 CD-PILLARS。
**Expected（预期）：** 返回 `CD-PILLARS: APPROVE`，并附理由说明每个支柱在概念中如何体现，以及文档中发现的任何强化或削弱信号。
**Assertions（断言）：**
- [ ] 结论严格为 APPROVE / CONCERNS / REJECT 之一
- [ ] 结论标记格式为 `CD-PILLARS: APPROVE`（门禁 ID 前缀、冒号、结论关键词）
- [ ] 理由按名称引用三个具体支柱，而非泛泛的创意建议
- [ ] 输出保持在创意范围内——不评论引擎可行性或冲刺排期

### Case 2: Out-of-domain request — redirects or escalates（领域外请求——重定向或升级）
**Scenario（场景）：** 开发者请求 creative-director 审查一个用于存储玩家存档数据的 PostgreSQL 模式设计方案。
**Expected（预期）：** 代理拒绝评估该模式设计，并重定向到 technical-director。
**Assertions（断言）：**
- [ ] 不对模式设计做出任何有约束力的决定
- [ ] 明确指出 `technical-director` 是正确的处理者
- [ ] 可以注明数据模型是否有创意层面的影响（例如追踪哪些玩家数据），但完全将结构决策交由 technical-director

### Case 3: Gate verdict — correct vocabulary（门禁结论——正确的词汇）
**Scenario（场景）：** 提交了"制作（Crafting）"系统的 GDD（游戏设计文档，Game Design Document）。第 4 节（公式）定义了一个惩罚探索行为的资源衰减公式，这与"玩家幻想（Player Fantasy）"章节中提倡"无忧无虑漫游的自由"相矛盾。请求标记为 CD-GDD-ALIGN。
**Expected（预期）：** 返回 `CD-GDD-ALIGN: CONCERNS`，并具体引用公式行为与玩家幻想陈述之间的矛盾。
**Assertions（断言）：**
- [ ] 结论严格为 APPROVE / CONCERNS / REJECT 之一——而非自由文本
- [ ] 结论标记格式为 `CD-GDD-ALIGN: CONCERNS`
- [ ] 理由引用或直接提及 GDD 第 4 节（公式）和玩家幻想章节
- [ ] 不规定具体的公式修复方案——这属于 systems-designer 的职责

### Case 4: Conflict escalation — correct parent（冲突升级——正确的上级）
**Scenario（场景）：** technical-director 提出核心循环机制（实时分支对话）的实现成本过高，并建议砍掉该功能。creative-director 基于创意理由表示反对。
**Expected（预期）：** creative-director 承认技术约束，不推翻 technical-director 的可行性评估，但保留定义创意目标是什么的权力。对于冲突本身，creative-director 是最高级别的创意升级点，在倡导设计意图的同时将实现可行性交由 technical-director 决定。解决路径是双方共同向用户呈现权衡选项。
**Assertions（断言）：**
- [ ] 不单方面推翻 technical-director 的可行性顾虑
- [ ] 明确区分"我们希望达到的创意效果"和"如何实现它"
- [ ] 提出向用户呈现权衡选项而非单方面解决
- [ ] 不声称拥有实现决策权

### Case 5: Context pass — uses provided context（上下文传递——使用提供的上下文）
**Scenario（场景）：** 代理收到一个门禁上下文块，其中包含游戏支柱文档（`design/gdd/pillars.md`）和一份待审查的新机制规格。支柱文档定义了"玩家主导性（player authorship）"、"后果永久性（consequence permanence）"和"世��响应性（world responsiveness）"三大核心支柱。
**Expected（预期）：** 评估使用所提供文档中的确切支柱词汇，而非泛泛的创意启发原则。任何批准或顾虑都需回溯到一个或多个所述支柱。
**Assertions（断言）：**
- [ ] 使用所提供上下文文档中的确切支柱名称
- [ ] 不生成与所提供支柱脱节的泛泛创意反馈
- [ ] 引用与被审查机制最相关的一个或多个具体支柱
- [ ] 不引用所提供文档中不存在的支柱

---

## Protocol Compliance（协议合规）

- [ ] 仅使用 APPROVE / CONCERNS / REJECT 词汇返回结论
- [ ] 保持在声明的创意领域内
- [ ] 通过向用户呈现权衡选项而非单方面推翻来解决冲突
- [ ] 在输出中使用门禁 ID（例如 `CD-PILLARS: APPROVE`），而非行内散文式结论
- [ ] 不做出有约束力的跨领域决策（技术、生产、美术执行）

---

## Coverage Notes（覆盖说明）
- 多门禁场景（如单个提交同时触发 CD-PILLARS 和 CD-GDD-ALIGN）未覆盖——推迟到集成测试。
- CD-PHASE-GATE（完整阶段推进）涉及综合多个子门禁结果；此复杂情况推迟处理。
- 玩法测试报告解读（CD-PLAYTEST）未覆盖——当 playtest-report 技能产生结构化输出时应添加专用用例。
- 与 art-director 在视觉支柱对齐方面的交互未覆盖。
