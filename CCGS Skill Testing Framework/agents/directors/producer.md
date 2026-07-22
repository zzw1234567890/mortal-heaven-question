
# Agent Test Spec: producer（制作人）

## Agent Summary（代理概述）
**Domain owned（所属领域）：** Scope management, sprint planning validation, milestone tracking, epic prioritization, production phase gate.
范围管理、冲刺（Sprint）计划验证、里程碑（Milestone）跟踪、Epic 优先级排序、生产阶段门禁（Phase Gate）。
**Does NOT own（不拥有的领域）：** Game design decisions (creative-director / game-designer), technical architecture (technical-director), creative direction.
游戏设计决策（creative-director / game-designer）、技术架构（technical-director）、创意方向。
**Model tier（模型层级）：** Opus（多文档综合评审，高风险的阶段门禁裁定）。
**Gate IDs handled（负责的门禁 ID）：** PR-SCOPE, PR-SPRINT, PR-MILESTONE, PR-EPIC, PR-PHASE-GATE.

---

## Static Assertions (Structural)（静态断言——结构性）

通过阅读代理的 `.claude/agents/producer.md` frontmatter 进行验证：

- [ ] `description:` 字段存在且领域特定（提及范围、冲刺、里程碑、生产——而非泛泛而谈）
- [ ] `allowed-tools:` 列表主要以读取为主；仅当冲刺/里程碑文件需要解析时才包含 Bash
- [ ] 模型层级为 `claude-opus-4-6`（依据 coordination-rules.md：具有门禁综合评审职能的总监为 Opus）
- [ ] 代理定义未声称对设计决策或技术架构拥有权威

---

## Test Cases（测试用例）

### Case 1: In-domain request — appropriate output format（领域内请求——合适的输出格式）
**Scenario（场景）：** 提交第 7 个冲刺的冲刺计划。该计划涵盖 4 名团队成员在 2 周内完成 12 个故事点（Story Points）。过去 3 个冲刺的历史平均速度（Velocity）为 11.5 点。请求标记为 PR-SPRINT。
**Expected（预期）：** 返回 `PR-SPRINT: REALISTIC`，理由中说明该计划在历史速度的一个标准差范围内，且产能看似匹配。
**Assertions（断言）：**
- [ ] 结论严格为 REALISTIC / CONCERNS / UNREALISTIC 之一
- [ ] 结论标记格式为 `PR-SPRINT: REALISTIC`
- [ ] 理由引用具体的故事点数量和历史速度数据
- [ ] 输出保持在生产范围内——不评论这些故事设计得好不好或技术上是否合理

### Case 2: Out-of-domain request — redirects or escalates（领域外请求——重定向或升级）
**Scenario（场景）：** 团队成员要求 producer 评估游戏的"按重量计库存（weight-based inventory）"机制是否好玩、有吸引力。
**Expected（预期）：** 代理拒绝评估游戏体验，并重定向到 game-designer 或 creative-director。
**Assertions（断言）：**
- [ ] 不对机制的设计质量做出有约束力的评估
- [ ] 明确指出 `game-designer` 或 `creative-director` 是正确的处理者
- [ ] 可以注明该机制的范围是否有生产影响（例如对其他系统的依赖），但将所有设计评估交由他人

### Case 3: Gate verdict — correct vocabulary（门禁结论——正确的词汇）
**Scenario（场景）：** 一个新功能提案要求在仅计划了两大系统的里程碑中加入三个新系统（制作、天气和阵营声望）。这些新增内容均未出现在当前里程碑计划中。请求标记为 PR-SCOPE。
**Expected（预期）：** 返回 `PR-SCOPE: CONCERNS`，具体识别三个未计划系统及其在里程碑范围文档中的缺失。
**Assertions（断言）：**
- [ ] 结论严格为 REALISTIC / CONCERNS / UNREALISTIC 之一——而非自由文本
- [ ] 结论标记格式为 `PR-SCOPE: CONCERNS`
- [ ] 理由指出三个被添加出范围的系统名称
- [ ] 不评估这些系统设计得好不好——只评估它们是否符合计划

### Case 4: Conflict escalation — correct parent（冲突升级——正确的上级）
**Scenario（场景）：** game-designer 希望添加一个后期新增的机制（动态天气影响所有游戏系统），而 technical-director 警告这将需要额外 3 个冲刺。game-designer 和 technical-director 就是否继续存在分歧。
**Expected（预期）：** Producer 不偏袒任何一方——不评判该机制是否值得添加（设计决策）或是否可行（技术决策）。Producer 量化生产影响（3 个冲刺的延迟、里程碑延期风险），向用户呈现权衡选项，并遵循 coordination-rules.md 的冲突解决方案：升级至共享上级（此处将冲突提交给用户决策，因为 creative-director 和 technical-director 均为最高层级）。
**Assertions（断言）：**
- [ ] 以具体术语量化生产影响（冲刺数量、里程碑日期延期）
- [ ] 不做出有约束力的设计或技术决策
- [ ] 向用户展示冲突，并清晰说明范围影响
- [ ] 引用 coordination-rules.md 冲突解决协议（升级至共享上级或用户）

### Case 5: Context pass — uses provided context（上下文传递——使用提供的上下文）
**Scenario（场景）：** 代理收到一个门禁上下文块，其中包含当前里程碑截止日期（距今 8 周）和过去 4 个冲刺的速度数据（8、10、9、11 点）。提交了一份包含 14 个故事点的冲刺计划。
**Expected（预期）：** 评估使用所提供的速度数据预测 14 点是否可实现，并引用 8 周里程碑窗口评估当前冲刺的范围是否留有足够的缓冲。
**Assertions（断言）：**
- [ ] 使用所提供上下文中的具体速度数据（而非泛泛的估算）
- [ ] 在产能评估中引用 8 周截止日期
- [ ] 计算或估算里程碑窗口内的剩余冲刺数量
- [ ] 不给出与所提供截止日期和速度数据脱节的泛泛范围建议

---

## Protocol Compliance（协议合规）

- [ ] 仅使用 REALISTIC / CONCERNS / UNREALISTIC 词汇返回结论
- [ ] 保持在声明的生产领域内
- [ ] 通过量化范围影响并呈现给用户来升级设计/技术冲突
- [ ] 在输出中使用门禁 ID（例如 `PR-SPRINT: REALISTIC`），而非行内散文式结论
- [ ] 不做出有约束力的游戏设计或技术架构决策

---

## Coverage Notes（覆盖说明）
- PR-EPIC（Epic 级别优先级排序）未覆盖——当 /create-epics 技能产生结构化 Epic 文档时应添加专用用例。
- PR-MILESTONE（里程碑健康度审查）未覆盖——推迟到与 /milestone-review 技能集成。
- PR-PHASE-GATE（完整生产阶段推进）涉及综合多个子门禁结果，推迟处理。
- 多冲刺燃尽图（Burndown）和速度趋势分析未覆盖。
