
# Skill 测试规格：/team-release

## Skill 概述

编排发布团队（release team）完成从发布候选到部署及发布后监控的 7 阶段流水线。协调
release-manager、qa-lead、devops-engineer、producer、security-engineer（可选，在线/多人游戏必需）、
network-programmer（可选，多人游戏必需）、analytics-engineer 和 community-manager。
第 3 阶段代理并行运行。以放行/不放行（go/no-go）决策结束；如果 producer 调用 NO-GO，
则跳过第 6 阶段的部署。以发布后监控计划收尾。

---

## 静态断言（结构性）

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含结论关键词：COMPLETE、BLOCKED
- [ ] 在 File Write Protocol 章节中包含 "May I write" 用语（委托给子代理）
- [ ] 具有 File Write Protocol 章节，说明编排器不直接写入文件
- [ ] 具有 Error Recovery Protocol 章节，包含四个恢复选项（浮现 / 评估 / 提供选项 / 部分报告）
- [ ] 末尾有下一步交接，引用发布后监控、`/retrospective` 和 `production/stage.txt`
- [ ] 在需要用户批准的阶段转换处使用 `AskUserQuestion`
- [ ] 第 3 阶段代理（qa-lead、devops-engineer，以及可选的 security-engineer、network-programmer）明确声明为并行运行
- [ ] 第 6 阶段（部署）以第 5 阶段的 GO 决策为条件
- [ ] security-engineer 被描述为在线功能/玩家数据的条件依赖 —— 并非总是启动

---

## 测试用例

### 用例 1：顺利路径（单人游戏）—— 所有阶段完成，版本已部署

**前置条件（Fixture）：**
- `production/stage.txt` 存在且包含 Production 或之后阶段
- 里程碑验收条件全部满足（producer 可确认）
- 无在线功能、无多人游戏、无玩家数据收集
- 当前分支上所有 CI 构建干净
- 无未关闭的 S1/S2 bug
- `production/sprints/` 包含此里程碑的已完成冲刺故事

**输入：** `/team-release v1.0.0`

**预期行为：**
1. 第 1 阶段：通过 Task 启动 `producer`；确认所有里程碑验收条件已满足；识别任何推迟的范围；生成发布授权；向用户展示；AskUserQuestion：用户在第 2 阶段前批准
2. 第 2 阶段：通过 Task 启动 `release-manager`；从商定的提交创建发布分支；更新版本号；调用 `/release-checklist`；冻结分支；输出：分支名称和清单；AskUserQuestion：用户在第 3 阶段前批准
3. 第 3 阶段（并行）：同时发出 `qa-lead`（回归测试套件、关键路径签核）和 `devops-engineer`（构建产物、CI 验证）的 Task 调用；security-engineer 不启动（无在线功能）；network-programmer 不启动（无多人游戏）；两者均成功完成
4. 第 4 阶段：验证本地化字符串全部翻译完成；`analytics-engineer` 验证遥测在发布构建中正确触发；性能基准测试通过；生成签核
5. 第 5 阶段：通过 Task 启动 `producer`；收集来自 qa-lead、release-manager、devops-engineer 的签核；无未关闭的阻塞问题；producer 宣布 GO；AskUserQuestion：用户看到 GO 决策并确认部署
6. 第 6 阶段：启动 `release-manager` + `devops-engineer`（并行）；在版本控制中标记发布；调用 `/changelog`；部署到预发布环境；冒烟测试通过；部署到生产环境；同时启动 `community-manager` 通过 `/patch-notes v1.0.0` 最终确定补丁说明并准备发布公告
7. 第 7 阶段：release-manager 生成发布报告；producer 更新里程碑跟踪；qa-lead 开始监控回归问题；community-manager 发布沟通内容；analytics-engineer 确认实时仪表板健康
8. 结论：COMPLETE —— 发布已执行并部署

**断言：**
- [ ] 第 3 阶段 qa-lead 和 devops-engineer 的 Task 调用同时发出，而非顺序执行
- [ ] 当游戏无在线功能、多人游戏或玩家数据时，security-engineer 不启动
- [ ] 第 5 阶段 producer 在宣布 GO 前收集所有必需方的签核
- [ ] 第 6 阶段部署仅在用户确认 GO 决策后开始
- [ ] 第 6 阶段由 release-manager 调用 `/changelog`（而非直接写入）
- [ ] 第 6 阶段由 community-manager 调用 `/patch-notes v1.0.0`
- [ ] 第 7 阶段监控计划包含 48 小时发布后监控承诺
- [ ] 后续步骤建议在成功部署后将 `production/stage.txt` 更新为 `Live`
- [ ] 最终输出中出现结论：COMPLETE

---

### 用例 2：放行/不放行：NO —— 第 3 阶段发现 S1 bug，跳过部署

**前置条件（Fixture）：**
- v0.9.0 的发布候选分支存在
- qa-lead 在第 3 阶段回归测试中在主菜单发现一个先前未报告的 S1 崩溃
- devops-engineer 构建干净，产物已就绪
- producer 已知晓 S1 bug

**输入：** `/team-release v0.9.0`

**预期行为：**
1. 第 1–2 阶段正常完成；发布候选已创建
2. 第 3 阶段（并行）：devops-engineer 返回干净的构建签核；qa-lead 返回发现 S1 bug 且回归测试套件失败；qa-lead 宣布质量关口：NOT PASSED
3. 编排器立即浮现 qa-lead 结果："QA-LEAD：发现 S1 bug —— [崩溃描述]。质量关口：NOT PASSED。"
4. 第 4 阶段谨慎继续或被暂停（AskUserQuestion：继续第 4 阶段还是跳到第 5 阶段做放行/不放行决策？）
5. 第 5 阶段：通过 Task 启动 `producer`；producer 收到 qa-lead 的 NOT PASSED 结论；无 S1 签核可用；producer 宣布 NO-GO 并附理由："S1 bug [ID] 未关闭且未解决。发布不安全。"
6. AskUserQuestion：向用户展示 NO-GO 决策和 S1 bug 详情；选项：修复 bug 并重新运行、推迟发布、或覆盖（附记录在案的理由）
7. 第 6 阶段（部署）完全跳过 —— 无分支标记、无预发布部署、无生产部署
8. 第 6 阶段中 community-manager 不启动（无部署可宣布）
9. Skill 以部分报告结束，总结已完成内容（第 1–5 阶段）和已跳过内容（第 6 阶段）及原因
10. 结论：BLOCKED —— 发布未部署

**断言：**
- [ ] qa-lead 的 S1 bug 发现结果在第 3 阶段完成后立即向用户浮现 —— 不会压制到第 5 阶段
- [ ] producer 的 NO-GO 决策明确引用 S1 bug 和质量关口结果
- [ ] 当 producer 宣布 NO-GO 时，第 6 阶段部署完全跳过
- [ ] NO-GO 时 community-manager 不启动用于补丁说明或发布公告
- [ ] 部分报告明确说明哪些阶段已完成、哪些已跳过及原因
- [ ] 结论：BLOCKED（非 COMPLETE）当因 NO-GO 跳过部署时
- [ ] AskUserQuestion 向用户提供解决选项（修复并重新运行 / 推迟 / 附理由覆盖）
- [ ] 覆盖路径（如选择）要求用户在进入第 6 阶段前提供记录在案的理由

---

### 用例 3：在线游戏的安全审计 —— 第 3 阶段启动 security-engineer

**前置条件（Fixture）：**
- 游戏具有多人游戏功能并存储玩家账户数据
- v2.1.0 的发布候选已就绪
- qa-lead 和 devops-engineer 均返回干净的签核
- 根据团队组成规则，安全审计是必需的

**输入：** `/team-release v2.1.0`

**预期行为：**
1. 第 1–2 阶段正常完成
2. 第 3 阶段（并行）：编排器检测到游戏具有在线/多人游戏功能和玩家数据；同时发出 `qa-lead`、`devops-engineer` 和 `security-engineer` 的 Task 调用；还为网络代码稳定性签核启动 `network-programmer`
3. security-engineer 进行发布前安全审计：审查认证流程、反作弊存在性、数据隐私合规性；返回签核
4. network-programmer 验证延迟补偿、重连处理和负载下的带宽；返回签核
5. 全部四个第 3 阶段代理完成；其结果在第 4 阶段开始前收集
6. 第 5 阶段：producer 在做出放行/不放行决策前收集全部四个第 3 阶段代理（qa-lead、devops-engineer、security-engineer、network-programmer）的签核
7. 剩余阶段正常进行至 COMPLETE

**断言：**
- [ ] 当游戏具有在线功能、多人游戏或玩家数据时，第 3 阶段启动 security-engineer —— 不会跳过
- [ ] 当游戏具有多人游戏时，第 3 阶段启动 network-programmer
- [ ] 全部四个第 3 阶段 Task 调用（qa-lead、devops-engineer、security-engineer、network-programmer）同时发出
- [ ] security-engineer 审计涵盖认证、反作弊和数据隐私合规性
- [ ] 第 5 阶段 producer 签核收集包括 security-engineer（四个参与方，而非两个）
- [ ] 第 6 阶段部署在 security-engineer 签核前不会开始
- [ ] 对于具有玩家数据的游戏，Skill 不会将 security-engineer 视为可选项

---

### 用例 4：本地化遗漏 —— 未翻译字符串阻止发布

**前置条件（Fixture）：**
- v1.2.0 的发布候选已就绪
- 第 3 阶段（qa-lead、devops-engineer）完成，签核干净
- 第 4 阶段：本地化验证检测到法语语言环境中 47 个未翻译字符串（法语是游戏本地化范围内的支持语言）
- localization-lead 可作为可委托代理使用

**输入：** `/team-release v1.2.0`

**预期行为：**
1. 第 1–3 阶段完成，签核干净
2. 第 4 阶段：本地化验证步骤检测到未翻译字符串；识别出法语语言环境中的 47 个字符串；localization-lead（如可用）被启动以评估严重性
3. 编排器浮现："本地化遗漏：在法语语言环境中发现 47 个未翻译字符串。本地化签核在发布前是必需的。"
4. AskUserQuestion：提供选项 —— (a) 修复翻译并重新运行第 4 阶段，(b) 从本次发布中移除法语语言环境，(c) 按现状发布，附带已知问题说明
5. 如果用户选择 (a)：在提供翻译后重新运行第 4 阶段；skill 等待本地化签核
6. 第 5 阶段放行/不放行决策在本地化签核未决期间不进行
7. 发布被阻止（不进入第 6 阶段），直到本地化问题解决或用户明确豁免

**断言：**
- [ ] 第 4 阶段的本地化验证检测到未翻译字符串并计数（不仅仅是"缺少一些字符串"）
- [ ] 所支持语言环境的未翻译字符串在第 5 阶段前阻止流水线
- [ ] 使用 AskUserQuestion 向用户提供解决选择 —— skill 不会自动豁免
- [ ] 本地化签核未决期间不调用第 5 阶段放行/不放行
- [ ] 如果用户选择重新运行第 4 阶段：skill 不需要从第 1 阶段重新开始
- [ ] 如果用户明确豁免（按现状发布）：豁免记录在发布报告（第 7 阶段）中作为已知问题
- [ ] Skill 不会编造翻译字符串来解除自身阻塞

---

### 用例 5：无参数 —— Skill 推断版本或询问

**前置条件（变体 A —— 里程碑数据存在）：**
- `production/milestones/` 存在，包含里程碑文件；最近的里程碑是 "v1.1.0 — Gold"
- `production/session-state/active.md` 引用了一个版本或里程碑

**前置条件（变体 B —— 无可发现的版本）：**
- `production/milestones/` 不存在
- `production/session-state/active.md` 未引用版本
- 无可用以推断版本的 git 标签

**输入：** `/team-release`（无参数）

**预期行为（变体 A）：**
1. 第 1 阶段：未提供参数；读取 `production/session-state/active.md`；读取 `production/milestones/` 中最近的里程碑文件
2. 推断 v1.1.0 为目标版本；报告"未提供版本参数 —— 从里程碑数据推断为 v1.1.0。继续执行。"
3. 在开始第 1 阶段之前通过 AskUserQuestion 确认："正在发布 v1.1.0。是否正确？"
4. 如同输入为 `/team-release v1.1.0` 继续执行

**预期行为（变体 B）：**
1. 第 1 阶段：未提供参数；读取可用的状态文件 —— 未发现版本
2. 使用 AskUserQuestion："应该发布哪个版本号？（例如 v1.0.0）"
3. 等待用户输入后再继续

**断言：**
- [ ] 未提供参数时，Skill 不会默认使用硬编码版本字符串
- [ ] 在询问之前，Skill 读取 `production/session-state/active.md` 和里程碑文件（变体 A）
- [ ] 推断的版本在继续前通过 AskUserQuestion 与用户确认（变体 A）
- [ ] 当无可发现的版本时，使用 AskUserQuestion —— skill 不会猜测（变体 B）
- [ ] 里程碑文件缺失时 Skill 不会报错 —— 它回退到询问用户（变体 B）

---

## 协议合规性

- [ ] 在每个阶段转换关口使用 `AskUserQuestion`（第 1 阶段后、第 2 阶段后、第 3/4 阶段后如有问题、第 5 阶段放行/不放行后）
- [ ] 第 3 阶段代理始终作为并行 Task 调用发出 —— qa-lead 和 devops-engineer 从不顺序执行
- [ ] security-engineer 根据游戏功能有条件启动 —— 当功能存在时从不静默跳过
- [ ] File Write Protocol：编排器从不直接调用 Write/Edit —— 所有写入委托给子代理或子技能
- [ ] 第 6 阶段部署严格以第 5 阶段 GO 结论为条件 —— 从不自动触发
- [ ] 错误恢复：任何 BLOCKED 代理在继续到依赖阶段前立即浮现
- [ ] 如果任何阶段失败或流水线停止，始终产出部分报告（用例 2）
- [ ] 结论：COMPLETE 仅在部署完成时；BLOCKED 当放行/不放行为 NO 或存在未解决的硬性阻塞
- [ ] 后续步骤始终包括 48 小时发布后监控、`/retrospective` 建议以及将 `production/stage.txt` 更新为 `Live`

---

## 覆盖说明

- 第 7 阶段发布后操作（发布报告、里程碑跟踪、社区发布、仪表板监控）由用例 1 隐式验证。
  不需要单独的边界用例，因为第 7 阶段无关口且没有阻塞失败模式。
- "devops-engineer 构建失败"路径未单独测试 —— 它会在第 3 阶段以 BLOCKED 结果浮现，
  并遵循标准错误恢复协议（浮现 → 评估 → AskUserQuestion 选项）。这通过静态断言的错误
  恢复检查在结构上得到验证。
- 并行的第 4 阶段路径（本地化 + 性能 + 分析与第 3 阶段同时进行）是 skill 中的记录选项
  （"如果资源可用，可以与第 3 阶段并行运行"）。用例 4 测试第 4 阶段作为顺序关口；
  并行变体留给 skill 的实现判断。
- 多人游戏的 `network-programmer` 签核路径作为用例 3 的一部分验证，而非单独用例，
  因为它遵循与 security-engineer 相同的并行启动模式。
- 用例 2 中的"附记录在案的理由覆盖 NO-GO"路径被引用但未详测试 ——
  它是 skill 必须支持的逃生舱，其存在由用例 2 的 AskUserQuestion 选项断言验证。
