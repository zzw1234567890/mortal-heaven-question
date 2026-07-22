
# Agent Test Spec: audio-director（音频总监）

## Agent Summary（代理概述）
**Domain owned（所属领域）：** Music direction and palette, sound design philosophy, audio implementation strategy, mix balance, audio aspects of phase gates.
音乐方向与调色板、音效设计理念、音频实现策略、混音平衡、阶段门禁（Phase Gate）的音频方面。
**Does NOT own（不拥有的领域）：** Visual design (art-director), code implementation (lead-programmer), narrative story content (narrative-director), UX interaction flows (ux-designer).
视觉设计（art-director）、代码实现（lead-programmer）、叙事故事内容（narrative-director）、UX 交互流程（ux-designer）。
**Model tier（模型层级）：** Sonnet（单系统分析——音频方向与规格审查）。
**Gate IDs handled（负责的门禁 ID）：** AD-VISUAL（阶段门禁的音频方面；在音频维度中可作为 AD-PHASE-GATE 的一部分被引用）。

---

## Static Assertions (Structural)（静态断言——结构性）

通过阅读代理的 `.claude/agents/audio-director.md` frontmatter 进行验证：

- [ ] `description:` 字段存在且领域特定（提及音乐方向、音效设计、混音、音频实现——而非泛泛而谈）
- [ ] `allowed-tools:` 列表以读取为主；除非音频资产管线检查有正当理由，否则不包含 Bash
- [ ] 模型层级为 `claude-sonnet-4-6`（依据 coordination-rules.md）
- [ ] 代理定义未声称对视觉设计、代码实现或叙事内容拥有权威

---

## Test Cases（测试用例）

### Case 1: In-domain request — appropriate output format（领域内请求——合适的输出格式）
**Scenario（场景）：** 提交一份游戏"探索（Exploration）"音乐层的音频规格文档。该规格定义了一个使用分层音轨（Stem）的生成式环境系统，这些音轨根据环境密度动态变化，旨在强化"鲜活的世��（lived-in world）"这一支柱。音色调色板（稀疏、有机、略带忧郁）与已确立的设计支柱相匹配。
**Expected（预期）：** 返回 `APPROVED`，并附理由确认基于分层音轨的方法支持动态响应性，且音色调色板与支柱词汇一致。
**Assertions（断言）：**
- [ ] 结论严格为 APPROVED / NEEDS REVISION 之一
- [ ] 理由引用具体支柱（"鲜活的世��"）以及音频规格如何支撑该支柱
- [ ] 输出保持在音频范围内——不评论环境的视觉设计或 UI 布局
- [ ] 结论明确标注上下文（例如"音频规格审查：APPROVED"）

### Case 2: Out-of-domain request — redirects or escalates（领域外请求——重定向或升级）
**Scenario（场景）：** 开发者请求 audio-director 评估音频设置菜单的 UI 流程（屏幕和选项的序列）是否直观且组织良好。
**Expected（预期）：** 代理拒绝评估 UI 交互流程，并重定向到 ux-designer。
**Assertions（断言）：**
- [ ] 不对 UI 流程或信息架构做出任何有约束力的决定
- [ ] 明确指出 `ux-designer` 是正确的处理者
- [ ] 可以注明设置菜单的音频特定需求（例如"必须包含独立的主音量、音乐和音效滑块"），但将流程和布局决策交由 ux-designer

### Case 3: Gate verdict — correct vocabulary（门禁结论——正确的词汇）
**Scenario（场景）：** 提交最终 Boss 战的音乐提示（Music Cue）。该曲目是一首欢快的大调管弦乐作品，节奏较快。而该战斗的游戏支柱和叙事背景指定为"恐惧、宿命感和悲剧性的牺牲"。该音频提示的情感基调与预期的情感节拍直接矛盾。
**Expected（预期）：** 返回 `NEEDS REVISION`，具体引用情感不匹配：曲目的欢快/大调/快节奏特征与支柱和叙事背景中预期的恐惧/宿命感/牺牲情感目标不符。
**Assertions（断言）：**
- [ ] 结论严格为 APPROVED / NEEDS REVISION 之一——而非自由文本
- [ ] 理由指出与情感目标冲突的具体音乐特征
- [ ] 引用来自游戏支柱或叙事背景的具体情感目标
- [ ] 提供可操作的修订方向（例如"转为小调、放慢节奏、减少合奏密度"）

### Case 4: Conflict escalation — correct parent（冲突升级——正确的上级）
**Scenario（场景）：** sound-designer 提议使用基于实时射线检测的物理查询来实现音频遮挡（Audio Occlusion）（技术方案）。technical-artist 认为这成本过高，提议改用基于区域的触发器（Zone-Based Trigger）系统。双方一致认为遮挡效果是可取的；冲突纯粹在于实现方法。
**Expected（预期）：** audio-director 决定所需的音频行为（遮挡听起来应该是什么效果、何时应该激活），然后将实现方式的决策交由 technical-artist 或 lead-programmer 作为实现专家。audio-director 不做出技术实现选择。
**Assertions（断言）：**
- [ ] 清晰定义所需的音频行为（玩家应该听到什么、什么时候听到）
- [ ] 明确将实现方式（射线检测 vs. 区域触发器）交由 `lead-programmer` 或 `technical-artist`
- [ ] 不单方面选择技术实现方法
- [ ] 清晰界定交接："audio-director 负责做什么，技术负责人负责怎么做"

### Case 5: Context pass — uses provided context（上下文传递——使用提供的上下文）
**Scenario（场景）：** 代理收到一个门禁上下文块，其中包含游戏三大支柱："涌现故事（emergent stories）"、"有意义的牺牲（meaningful sacrifice）"和"鲜活的世��（lived-in world）"。提交了一份环境音频的音效设计规格。
**Expected（预期）：** 评估将环境音频规格与所有三个支柱进行具体对照——音频如何支撑（或削弱）每个支柱？在理由中直接使用支柱词汇。
**Assertions（断言）：**
- [ ] 在评估中按名称引用所有三个提供的支柱
- [ ] 明确评估音频规格对每个支柱的贡献
- [ ] 不生成泛泛的音频方向建议——所有反馈均与所提供的支柱词汇关联
- [ ] 指出是否有任何支柱未被当前音频规格支撑，并标记

---

## Protocol Compliance（协议合规）

- [ ] 仅使用 APPROVED / NEEDS REVISION 词汇返回结论
- [ ] 保持在声明的音频领域内
- [ ] 将实现方式决策交由技术负责人
- [ ] 不使用与总监层级代理相同的门禁 ID 前缀格式（audio-director 在行内使用 APPROVED / NEEDS REVISION，但应仍引用门禁上下文）
- [ ] 不做出有约束力的视觉设计、UX、叙事或代码实现决策

---

## Coverage Notes（覆盖说明）
- 混音平衡审查（音乐、音效和对话之间的相对电平）未覆盖——应添加专用用例。
- 音频实现策略审查（中间件选择、流式传输方案）未覆盖。
- audio-director 与音频专家代理（若存在）之间的实现委派交互未覆盖。
- 本地化的音频影响（配音录制方向、特定语言的音乐节奏）未覆盖。
