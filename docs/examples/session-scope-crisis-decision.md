
# 示例会话：范围危机 — 战略决策制定

**上下文：** 独立开发者，项目第 8 周（第 2 个月），临近 Alpha 里程碑。

**危机：**
- Alpha 里程碑还有 2 周
- 制造系统（支柱 2）尚未实现
- 主程序员表示完整制造需要 3 周
- Alpha 时有投资人演示——必须展示所有支柱

**会话时长：** 约 25 分钟
**轮次：** 8
**结果：** 带文档化 ADR 的战略范围决策

---

## 第 1 轮：用户将问题上报给创意总监

**User:**
> 我们有问题。Alpha 还有 2 周。制造系统（支柱 2"涌现发现"）还没实现。主程序员说完整实现需要 3 周。但投资人演示在 Alpha，他们需要看到两个支柱（战斗 + 制造）。我该怎么办？

## 第 2 轮：创意总监收集完整上下文

**Agent (creative-director):**
> 这是一个经典的支柱 vs. 进度冲突——正是我在此帮助解决的。让我在推荐选项之前收集完整上下文。
>
> 首先，让我审阅相关文档：
> - `production/milestones/alpha.md`（里程碑定义）
> - `design/pillars.md`（什么是不可谈判的）
> - `design/gdd/crafting-system.md`（已设计的内容）
> - `production/sprints/sprint-current.md`（当前工作）
>
> [读取文档]
>
> **上下文已理解：**
> - 支柱 2："通过实验涌现发现"（制造是主要表达）
> - Alpha 成功标准："所有支柱以可玩形式展示"
> - 投资人演示目的：验证愿景并 securing 下一轮融资
> - 当前制造设计：基于标签的推理系统，12 个标签，约 50 个配方，渐进式提示解锁
>
> **澄清问题：**
> 1. Alpha 日期是**硬性**（投资人不会改期）还是**软性**（我们可以要求再多 1 周）？
> 2. 仍能展示支柱 2 的**最小制造**是什么？（一个配方？十个配方？完整标签系统？）
> 3. 如果制造从 Alpha 完全砍掉，什么会**崩坏**？（游戏还讲得通吗？）
> 4. 这个投资人关系有多**关键**？（锦上添花的融资 vs. 项目存亡的成败关键？）
> 5. **团队状态**如何？（因赶工而精疲力竭？精力充沛且需要时可以冲刺？）

## 第 3 轮：用户提供决策上下文

**User:**
> 1. 硬性日期——投资人专程飞来演示，不能改期
> 2. 我认为最小是：发现机制可用（标签系统）+ 10 个配方。不需要打磨。
> 3. 没有制造，Alpha 只展示战斗。那是愿景的 50%——投资人可能觉得这只是又一款战斗游戏
> 4. 成败关键。这位投资人是我们唯一的线索。无融资 = 项目死亡。
> 5. 就我一人独立，我还没精疲力竭。

## 第 4 轮：创意总监框定决策

**Agent:**
> 谢谢。现在我理解了真正利害所在。让我正确框定此决策：
>
> **核心问题：**
> 我们是交付完整制造并推迟 Alpha，交付简化制造并赶上 Alpha，还是砍掉制造并冒投资人看不到我们完整愿景的风险？
>
> **真正利害所在：**
> - **愿景完整性**：投资人能否看到支柱 2？
> - **进度信任**：我们是否守住对 Alpha 日期的承诺？
> - **项目存亡**：无融资 = 无游戏
> - **质量标准**：此演示是否接受"粗糙但可用"？
>
> **决策标准（按此场景的优先级排序）：**
> 1. **投资人信心**（最高——项目存亡依赖于此）
> 2. **支柱代表性**（高——他们需要看到完整愿景）
> 3. **进度完整性**（中——重要，但不如融资）
> 4. **打磨质量**（最低——垂直切片可以粗糙）
>
> 现在让我呈现三个战略选项...

## 第 5 轮：创意总监呈现带分析的选项

**Agent:**
> **选项 A：实现完整制造系统（3 周，Alpha 推迟 1 周）**
>
> **执行：**
> - 实现完整基于标签的系统，全部 50 个配方
> - 完整 UI 打磨，GDD 中的所有特性
> - 错过 Alpha 日期，重新安排投资人演示（+1 周）
>
> **优点：**
> - ✅ 支柱 2 以生产质量完整呈现
> - ✅ 无设计妥协
> - ✅ 第一印象打磨精良
>
> **缺点：**
> - ❌ 破坏投资人承诺（他们专程飞来原定日期）
> - ❌ 暗示进度管理问题（"如果他们推迟了 Alpha，会不会也推迟发布？"）
> - ❌ 可能比粗糙演示更损害投资人信任
>
> **风险：CRITICAL**
> - 投资人可能不改期（日程繁忙、其他机会）
> - 即使他们愿意，推迟也损害信誉
> - 鉴于硬性日期约束，不太可能成功
>
> **判定：不推荐** — 日期是硬性且不可谈判
>
> ---
>
> **选项 B：将制造简化为核心支柱（1.5 周，赶上 Alpha）**
>
> **执行：**
> - 仅实现核心标签发现机制
> - 10 个配方而非 50（足以展示系统）
> - 基本 UI（功能性，未打磨）
> - 无渐进式提示解锁（为演示清晰，技能 0 时所有标签可见）
> - 无失败尝试反馈系统（仅成功/失败）
>
> **范围："支柱 2 的垂直切片 (Vertical Slice)"**
> - 玩家可以透过组合带标签材料发现配方
> - 玩家可以学习标签模式并推理新配方
> - 支柱 2 的灵魂在场，只是未打磨
>
> **优点：**
> - ✅ 赶上 Alpha 截止（进度完整性保持）
> - ✅ 支柱 2 已展示（投资人看到完整愿景）
> - ✅ 核心机制可玩且可证明
> - ✅ 可用"Alpha → Beta 改进"作为叙事（"这是粗糙的，这是打磨的"）
>
> **缺点：**
> - ⚠️ 第一印象"粗糙"（但垂直切片本就预期粗糙）
> - ⚠️ 投资人可能觉得"这感觉小"（缓解：展示 Alpha 后扩展的路线图）
>
> **风险：中**
> - 投资人可能从 10 个配方"get"不到支柱（缓解：好的演示脚本解释愿景）
> - 可能感觉不完整（缓解：框定为"证明概念的垂直切片"）
>
> **判定：推荐** — 平衡所有约束
>
> ---
>
> **选项 C：从 Alpha 砍掉制造，专注战斗打磨（0 周，赶上 Alpha）**
>
> **执行：**
> - 仅以完整打磨的支柱 1（战斗）交付 Alpha
> - 用额外 2 周超级打磨战斗、添加内容、使其闪耀
> - 以"设计文档 + 概念图"呈现制造（不可玩）
>
> **优点：**
> - ✅ 零压力赶上截止
> - ✅ 呈现的内容是 AAA 级打磨
> - ✅ 无"半生不熟"观感风险
>
> **缺点：**
> - ❌ 支柱 2 未展示（愿景缺失 50%）
> - ❌ 投资人看到"又一款战斗游戏"——无差异化
> - ❌ 为"潜力"融资比"已证概念"更难
> - ❌ 若仅战斗不能打动他们，我们无退路
>
> **风险：高**
> - 投资人看不到这游戏的特别之处
> - 他们可能想"战斗不错，但 hook 在哪？"
> - 竞品也有战斗——我们需要展示差异化
>
> **判定：不推荐** — 对成败关键演示风险太高
>
> ---
>
> ## 我的建议：选项 B（简化制造核心）
>
> **理由：**
> 1. **投资人信心**：守住我们承诺的日期显示可靠性
> 2. **支柱可见性**：粗糙但可用 > 打磨但缺失。投资人投愿景，不投打磨。
> 3. **演示叙事**："这是 Alpha vs. Beta 的进展"很引人——展示轨迹
> 4. **风险缓解**：若制造不落地，战斗仍扎实。若我们砍制造（选项 C）而战斗单独不能打动他们，我们一无所有。
> 5. **历史先例**：Hades、Dead Cells、Slay the Spire 都展示了粗糙的 Early Access 垂直切片，投资人喜爱系统胜过打磨
>
> **选项 B 牺牲了什么：**
> - 打磨（垂直切片可接受）
> - 特性完整性（50 配方 → 10）
> - 渐进解锁（推迟到 Alpha 后）
>
> **选项 B 保护了什么：**
> - 进度信任
> - 支柱代表性
> - 愿景清晰
> - 项目存亡（融资 secured）
>
> **若你选择选项 B 的实现计划：**
> 1. 我将创建记录此范围决策的 ADR
> 2. 我将更新 `design/gdd/crafting-system.md`，加"Alpha Scope"标记
> 3. 我将向 gameplay-programmer 简报简化实现
> 4. 我将为你创建演示脚本：如何向投资人呈现 10 配方系统以展示 50 配方愿景
>
> **但这是你的决定。** 你比我都了解这位投资人。如果你相信他们更看重打磨而非支柱代表性，选项 C 可能对。如果你认为他们会原谅 1 周推迟，选项 A 在创作上最安全。
>
> 你的决定是什么？

## 第 6 轮：用户做决策

**User:**
> 选项 B。投资人是技术型的，会欣赏系统思维即使粗糙。让我们简化制造范围以赶上 Alpha。你能创建 ADR 并更新 GDD 吗？

## 第 7 轮：创意总监记录决策

**Agent:**
> 出色的决策。我将详尽记录以便未来的你理解我们为何做此选择。
>
> **创建中：**
> 1. ADR-007：Alpha 制造范围缩减
> 2. 更新 design/gdd/crafting-system.md，加 Alpha/Beta 范围标记
> 3. 更新 production/milestones/alpha.md 成功标准
> 4. 投资人演示脚本的呈现指引
>
> [创建文档]
>
> **ADR 摘要：**
> ```markdown
> ## Decision
> Simplify crafting system to core tag discovery mechanic (10 recipes)
> for Alpha milestone. Defer full implementation (50 recipes + progressive
> unlocks) to post-Alpha.
>
> ## Context
> - Alpha in 2 weeks (hard date, investor demo)
> - Full crafting requires 3 weeks
> - Investor demo is make-or-break for funding
>
> ## Consequences
> Positive:
> - Makes Alpha deadline, preserves investor trust
> - Both pillars demonstrated (rough but playable)
> - Can show Alpha→Beta improvement narrative
>
> Negative:
> - First impression is "rough"
> - Limited recipe variety
> - Missing progressive unlock system
>
> ## Validation Criteria
> We'll know this was the right choice if:
> - Investor demo successfully shows both pillars
> - Funding secured for next development phase
> - Post-Alpha sprint can implement full system without rework
> ```
>
> **更新的 GDD 标记：**
> ```markdown
> ## Detailed Rules
>
> ### Core Loop (**ALPHA SCOPE**)
> [Core mechanic description]
>
> ### Progressive Unlocks (**POST-ALPHA**)
> [Skill-based hint system - deferred]
>
> ### Recipe Catalog
> - Alpha: 10 recipes (demonstrates tag variety)
> - Beta: 50 recipes (full content)
> ```
>
> **演示脚本指引：**
> ```markdown
> ## Presenting Crafting to Investor (10-recipe Alpha)
>
> **Frame it as proof-of-concept:**
> "This is a vertical slice of the crafting pillar. You'll see 10 recipes
> here, but the SYSTEM supports unlimited recipes through tag combinations.
> Watch how players deduce patterns..."
>
> **Show, don't tell:**
> - Live demo: Discover 2 recipes on the fly
> - Explain: "Notice Fire+Water made Steam Potion. Now the player knows
>   Fire+Water is valid. They can deduce that Fire+Earth might work..."
> - Connect to pillar: "This is Emergent Discovery - the game teaches rules,
>   players become scientists."
>
> **Roadmap slide:**
> "Alpha: 10 recipes (proof of concept)
>  Beta: 50 recipes (content expansion)
>  Release: 100+ recipes (includes community-designed recipes)"
>
> **Emphasize systems:**
> "We're not making a content game, we're making a systems game. The tag
> system can generate endless combinations. We're building a platform for
> discovery, not a recipe database."
> ```
>
> 我可以继续写这些文档吗？

## 第 8 轮：用户批准并代理完成

**User:**
> 是的，创建所有这些文档并通知 gameplay-programmer 范围变更。

**Agent:**
> ✅ 完成！已创建/更新：
> - `docs/architecture/adr-007-alpha-crafting-scope.md`
> - `design/gdd/crafting-system.md`（添加 Alpha/Beta 范围标记）
> - `production/milestones/alpha.md`（更新成功标准）
> - `production/demo-script-investor-alpha.md`（新文件，含呈现指引）
>
> **已发送通知：**
>
> 致 `gameplay-programmer`：
> > "制造范围已为 Alpha 简化：仅核心标签机制 + 10 个配方。
> > 渐进解锁和完整配方集推迟到 Alpha 后。更新的
> > GDD 含实现指引。估计 1.5 周实现 Alpha 范围。"
>
> 致 `producer`：
> > "已做战略决策：简化制造以赶上 Alpha 截止。
> > ADR-007 记录理据。Sprint 计划需更新以反映新范围。"
>
> **后续步骤：**
> 1. Gameplay-programmer 可开始实现简化制造
> 2. 你可在投资人会议前练习演示脚本
> 3. Producer 将用新任务分解更新 sprint 计划
>
> **验证：**
> 我们将知道此决策正确当：
> - Alpha 按时发布，两支柱可玩
> - 投资人演示成功传达愿景
> - 为持续开发 secured 融资
>
> 祝演示顺利！这是正确的选择——对此受众而言愿景胜过打磨。

---

## 会话总结

**做得好的地方：**
- 创意总监在提议方案前先读上下文文档
- 提出 5 个澄清问题理解约束
- 正确框定决策（利害所在、评估标准）
- 呈现 3 个不同选项，附诚实优缺点
- 给出清晰建议并附理由，但交由用户决定
- 用 ADR 详尽记录决策并更新所有受影响文档
- 提供演示脚本帮助用户积极呈现决策

**关键协作时刻：**
- 第 2 轮：代理在跳到方案前收集完整上下文
- 第 3 轮：用户提供决策标准优先级（融资 > 进度 > 打磨）
- 第 5 轮：代理呈现 3 个选项，给出建议，但明确"这是你的决定"
- 第 6 轮：用户做战略决策
- 第 7 轮：代理提供演示脚本支持用户的呈现
- 第 8 轮：代理将决策级联到受影响方

**战略决策质量：**
- 用户做最终决定
- 代理用游戏开发理论和先例提供专家分析
- 权衡明确且诚实
- 决策已记录供未来参考
- 定义了成功标准用于验证

**已创建/更新的文件：**
- ADR-007（决策记录）
- 更新的制造 GDD，附范围标记
- 更新的 Alpha 里程碑定义
- 投资人演示脚本

**上下文使用：** 约 30%
**用户满意度：** 高——在完整信息下自信做出决策
