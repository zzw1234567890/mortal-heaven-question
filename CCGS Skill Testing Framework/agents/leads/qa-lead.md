
# 代理测试规范：qa-lead（QA 主管）

## 代理概述
**负责领域：** 测试策略、QL-STORY-READY 门禁、QL-TEST-COVERAGE 门禁、bug 严重程度分诊、发布质量门禁。
**不负责：** 功能实现（程序员）、游戏设计决策、创意方向、生产排期。
**模型层级：** Sonnet（单系统分析 —— story 就绪度与覆盖率评估）。
**处理的门禁 ID：** QL-STORY-READY、QL-TEST-COVERAGE。

---

## 静态断言（结构性）

通过读取代理的 `.claude/agents/qa-lead.md` frontmatter 验证：

- [ ] `description:` 字段存在且具有领域特异性（引用测试策略、story 就绪度、覆盖率、bug 分诊 —— 而非泛泛而谈）
- [ ] `allowed-tools:` 列表以读取为主；可包含用于读取 story 文件、测试文件和 coding-standards 的 Read；仅当需要运行测试命令时才包含 Bash
- [ ] 模型层级为 `claude-sonnet-4-6`（依据 coordination-rules.md）
- [ ] 代理定义未声称对实现决策或游戏设计拥有权威

---

## 测试用例

### 用例 1：领域内请求 —— 合适的输出格式
**场景：** 提交一个"玩家受到危险地块伤害"的 story 进行就绪度检查。该 story 有三条验收标准（AC）：(1) 玩家生命值按危险地块的伤害值减少，(2) 播放伤害视觉反馈，(3) 玩家在 0.5 秒内不能再次受到伤害（无敌窗口）。三条 AC 全部可度量且具体。请求标记为 QL-STORY-READY。
**预期：** 返回 `QL-STORY-READY: ADEQUATE`，理由中确认三条 AC 全部存在、具体且可测试。
**断言：**
- [ ] 判定结果恰好为 ADEQUATE / INADEQUATE 之一
- [ ] 判定标记格式为 `QL-STORY-READY: ADEQUATE`
- [ ] 理由引用 AC 的具体数量（3）并确认每条均可度量
- [ ] 输出保持在 QA 范围内 —— 不评论该机制设计得好不好

### 用例 2：领域外请求 —— 重定向或上报
**场景：** 开发者要求 qa-lead 为新物理系统实现自动化测试框架。
**预期：** 代理拒绝实现测试代码，并重定向到合适的程序员（gameplay-programmer 或 lead-programmer）。
**断言：**
- [ ] 不编写或提议代码实现
- [ ] 明确指出 `lead-programmer` 或 `gameplay-programmer` 是实现的正确处理者
- [ ] 可以定义测试应验证什么（测试策略），但把代码编写交给程序员

### 用例 3：门禁判定 —— 正确措辞
**场景：** 提交一个"战斗手感要响应迅速、有打击感"的 story 进行就绪度检查。唯一的验收标准写道："战斗应让玩家感觉良好。" 这是主观且不可度量的。请求标记为 QL-STORY-READY。
**预期：** 返回 `QL-STORY-READY: INADEQUATE`，明确指出不可度量的 AC，并给出使其可测试的指导（例如"输入到命中反馈的延迟 ≤ 100ms"）。
**断言：**
- [ ] 判定结果恰好为 ADEQUATE / INADEQUATE 之一 —— 不是自由文本
- [ ] 判定标记格式为 `QL-STORY-READY: INADEQUATE`
- [ ] 理由指出未满足可度量性要求的具体 AC
- [ ] 提供可操作的指导，说明如何改写 AC 使其可测试

### 用例 4：冲突上报 —— 正确的上级
**场景：** gameplay-programmer 和 qa-lead 就一个断言"敌人巡逻路径在 5 秒内访问所有路径点"的测试是否具有足够确定性、能否成为有效的自动化测试产生分歧。gameplay-programmer 认为时间变化性会导致测试不稳定（flaky）；qa-lead 认为可以接受。
**预期：** qa-lead 承认技术上的不稳定性顾虑，并上报给 lead-programmer，由其对自动化测试可接受的确定性标准做出技术裁决。
**断言：**
- [ ] 上报给 `lead-programmer` 就确定性标准做出技术裁决
- [ ] 不单方面否决 gameplay-programmer 的不稳定性顾虑
- [ ] 明确界定上报内容："这是技术标准问题，不是 QA 覆盖率问题"
- [ ] 不放弃覆盖率要求 —— 如果当前方案被裁定为不稳定，则要求提供确定性的替代方案

### 用例 5：上下文传递 —— 使用提供的上下文
**场景：** 代理收到一个门禁上下文块，其中包含 coding-standards.md 的测试标准章节，该章节规定：Logic 类 story 需要阻塞性的自动化单元测试；Visual/Feel 类 story 需要截图 + 主管签字（建议性）；Config/Data 类 story 需要冒烟检查通过（建议性）。一个分类为"Logic"类型的 story 仅以一份手动走查文档作为证据提交。
**预期：** 评估引用 coding-standards.md 中的具体测试证据要求，指出"Logic" story 需要自动化单元测试（而非仅手动走查），并返回 INADEQUATE，引用具体要求。
**断言：**
- [ ] 引用所提供上下文中的具体 story 类型分类（"Logic"）
- [ ] 引用 coding-standards.md 中 Logic story 的具体证据要求（自动化单元测试）
- [ ] 指出提交的证据类型（手动走查）对该 story 类型而言不充分
- [ ] 不将建议性级别的要求当作阻塞性要求来执行

---

## 协议合规性

- [ ] QL-STORY-READY 判定仅使用 ADEQUATE / INADEQUATE 措辞
- [ ] QL-TEST-COVERAGE 判定仅使用 ADEQUATE / INADEQUATE 措辞（发布门禁使用 PASS / FAIL）
- [ ] 保持在声明的 QA 与测试策略领域内
- [ ] 将技术标准争议上报给 lead-programmer
- [ ] 输出中使用门禁 ID（例如 `QL-STORY-READY: INADEQUATE`），而非行内散文式判定
- [ ] 不做出有约束力的实现或游戏设计决策

---

## 覆盖说明
- QL-TEST-COVERAGE（针对 sprint 或里程碑的整体覆盖率评估）未覆盖 —— 在有覆盖率报告可用时应补充专门用例。
- Bug 严重程度分诊（P0/P1/P2 分类）此处未覆盖 —— 推迟到 /bug-triage 技能集成。
- 发布质量门禁行为（PASS / FAIL 措辞变体）未覆盖。
- QL-STORY-READY 与 story done 标准（/story-done 技能）之间的交互未覆盖。
