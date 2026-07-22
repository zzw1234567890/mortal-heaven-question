
# Agent Test Spec: technical-director（技术总监）

## Agent Summary（代理概述）
**Domain owned（所属领域）：** System architecture decisions, technical feasibility assessment, ADR oversight and approval, engine risk evaluation, technical phase gate.
系统架构决策、技术可行性评估、ADR（架构决策记录，Architecture Decision Record）监督与批准、引擎风险评估、技术阶段门禁（Phase Gate）。
**Does NOT own（不拥有的领域）：** Game design decisions (creative-director / game-designer), creative direction, visual art style, production scheduling (producer).
游戏设计决策（creative-director / game-designer）、创意方向、视觉美术风格、生产排期（producer）。
**Model tier（模型层级）：** Opus（多文档综合评审，高风险的架构和阶段门禁裁定）。
**Gate IDs handled（负责的门禁 ID）：** TD-SYSTEM-BOUNDARY, TD-FEASIBILITY, TD-ARCHITECTURE, TD-ADR, TD-ENGINE-RISK, TD-PHASE-GATE.

---

## Static Assertions (Structural)（静态断言——结构性）

通过阅读代理的 `.claude/agents/technical-director.md` frontmatter 进行验证：

- [ ] `description:` 字段存在且领域特定（提及架构、可行性、ADR——而非泛泛而谈）
- [ ] `allowed-tools:` 列表可能包含用于架构文档的 Read；仅当技术检查需要时包含 Bash
- [ ] 模型层级为 `claude-opus-4-6`（依据 coordination-rules.md：具有门禁综合评审职能的总监为 Opus）
- [ ] 代理定义未声称对游戏设计决策或创意方向拥有权威

---

## Test Cases（测试用例）

### Case 1: In-domain request — appropriate output format（领域内请求——合适的输出格式）
**Scenario（场景）：** 提交一份"战斗系统"的架构文档。该文档描述了一个分层设计：输入层 → 游戏逻辑层 → 表现层，各层之间接口定义清晰。请求标记为 TD-ARCHITECTURE。
**Expected（预期）：** 返回 `TD-ARCHITECTURE: APPROVE`，并附理由确认系统边界划分正确且接口定义良好。
**Assertions（断言）：**
- [ ] 结论严格为 APPROVE / CONCERNS / REJECT 之一
- [ ] 结论标记格式为 `TD-ARCHITECTURE: APPROVE`
- [ ] 理由具体引用分层结构和接口定义——而非泛泛的架构建议
- [ ] 输出保持在技术范围内——不评论该机制是否有趣或是否符合创意愿景

### Case 2: Out-of-domain request — redirects or escalates（领域外请求——重定向或升级）
**Scenario（场景）：** 作家（Writer）请求 technical-director 审查并批准游戏开场过场动画的对话脚本。
**Expected（预期）：** 代理拒绝评估对话质量，并重定向到 narrative-director。
**Assertions（断言）：**
- [ ] 不对对话内容或结构做出任何有约束力的决定
- [ ] 明确指出 `narrative-director` 是正确的处理者
- [ ] 可以注明影响对话的技术约束（例如本地化字符串长度限制、数据格式），但将所有内容决策交由他人

### Case 3: Gate verdict — correct vocabulary（门禁结论——正确的词汇）
**Scenario（场景）：** 一个提议中的多人机制需要每帧对所有活跃实体进行射线检测（Raycasting）以判断视线（Line-of-Sight）。在预期玩家数量下（大区域内 1000 个实体），这相当于每帧 O(n²)。请求标记为 TD-FEASIBILITY。
**Expected（预期）：** 返回 `TD-FEASIBILITY: CONCERNS`，具体引用 O(n²) 复杂度以及使该方案在目标帧率下不可行的实体数量。
**Assertions（断言）：**
- [ ] 结论严格为 APPROVE / CONCERNS / REJECT 之一——而非自由文本
- [ ] 结论标记格式为 `TD-FEASIBILITY: CONCERNS`
- [ ] 理由包含具体的算法复杂度问题和实体数量阈值
- [ ] 建议至少一种替代方案（例如空间分区（Spatial Partitioning）、兴趣管理（Interest Management）），但不强制选择

### Case 4: Conflict escalation — correct parent（冲突升级——正确的上级）
**Scenario（场景）：** game-designer 希望对每个库存物品（同时显示数百个物品）进行实时物理模拟。technical-director 评估认为技术成本过高，建议简化模拟。game-designer 不同意，认为这对游戏手感至关重要。
**Expected（预期）：** technical-director 清楚陈述技术成本和约束，提出能够实现类似效果的可选实现方案，但明确将最终设计优先级决策交由 creative-director 作为玩家体验权衡的仲裁者。
**Assertions（断言）：**
- [ ] 用具体数据表达技术顾虑（例如性能预算、估算成本）
- [ ] 提出至少一种能在保留意图的同时降低成本的替代方案
- [ ] 明确将"这个代价是否值得"的决策交由 creative-director——不单方面砍掉功能
- [ ] 不声称有权推翻 game-designer 的设计意图

### Case 5: Context pass — uses provided context（上下文传递——使用提供的上下文）
**Scenario（场景）：** 代理收到一个门禁上下文块，其中包含目标平台限制：移动端、60fps 目标、2GB RAM 上限、不支持计算着色器（Compute Shader）。提交的提议架构包含一个 GPU 驱动的渲染管线。
**Expected（预期）：** 评估引用上下文中的具体硬件约束，指出计算着色器依赖与所述平台限制不兼容，并以这些具体细节返回 CONCERNS 或 REJECT 结论。
**Assertions（断言）：**
- [ ] 引用所提供的具体平台限制（移动端、2GB RAM、无计算着色器）
- [ ] 不提供与所提供约束脱节的泛泛性能建议
- [ ] 正确识别与平台限制冲突的架构组件
- [ ] 结论理由与所提供的上下文紧密关联，而非模板化警告

---

## Protocol Compliance（协议合规）

- [ ] 仅使用 APPROVE / CONCERNS / REJECT 词汇返回结论
- [ ] 保持在声明的技术领域内
- [ ] 将设计优先级冲突交由 creative-director
- [ ] 在输出中使用门禁 ID（例如 `TD-FEASIBILITY: CONCERNS`），而非行内散文式结论
- [ ] 不做出有约束力的游戏设计或创意方向决策

---

## Coverage Notes（覆盖说明）
- TD-ADR（架构决策记录批准）未覆盖——当 /architecture-decision 技能生成 ADR 文档时应添加专用用例。
- 针对特定引擎版本（例如 Godot 4.6 知识截止日期后的 API）的 TD-ENGINE-RISK 评估未覆盖——推迟到引擎专家集成测试。
- TD-PHASE-GATE（完整技术阶段推进）涉及综合多个子门禁结果，推迟处理。
- 多领域架构审查（例如同时涉及 TD-ARCHITECTURE 和 TD-ENGINE-RISK）未覆盖。
