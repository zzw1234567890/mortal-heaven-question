
# Skill 测试规格：/team-qa

## Skill 概述

编排质量保证（QA）团队完成一个 7 阶段的结构化测试周期。协调
qa-lead（策略、测试计划、签核报告）和 qa-tester（测试用例编写、bug 报告编写）。
涵盖范围检测、故事分类、QA 计划生成、冒烟检查关口、测试用例编写、手动 QA 执行（含 bug 报告），
以及最终签核报告，结论为 APPROVED / APPROVED WITH CONDITIONS / NOT APPROVED。
在第 5 阶段对独立故事使用并行 qa-tester 启动。

---

## 静态断言（结构性）

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含结论关键词：COMPLETE、BLOCKED
- [ ] 包含签核报告的结论关键词：APPROVED、APPROVED WITH CONDITIONS、NOT APPROVED
- [ ] 包含 QA 计划和签核报告的 "May I write" 用语
- [ ] 具有 Error Recovery Protocol 章节
- [ ] 在阶段转换处使用 `AskUserQuestion`，在继续前征得用户批准
- [ ] 第 4 阶段（冒烟检查）是硬性关口：FAIL 停止整个周期
- [ ] Bug 报告写入 `production/qa/bugs/`，命名格式为 `BUG-[NNN]-[short-slug].md`
- [ ] 后续步骤指导因结论而异（APPROVED / APPROVED WITH CONDITIONS / NOT APPROVED）
- [ ] 第 5 阶段中独立的 qa-tester 任务并行启动

---

## 测试用例

### 用例 1：顺利路径 —— 所有故事通过手动 QA，结论 APPROVED

**前置条件（Fixture）：**
- `production/sprints/sprint-03/` 存在，包含 4 个故事文件
- 故事为混合类型：1 个 Logic（逻辑）、1 个 Integration（集成）、2 个 Visual/Feel（视觉/感觉）
- 所有故事的验收条件均已填写
- `tests/smoke/` 包含冒烟测试列表；所有项目均可验证
- `production/qa/bugs/` 中不存在现有 bug

**输入：** `/team-qa sprint-03`

**预期行为：**
1. 第 1 阶段：读取 `production/sprints/sprint-03/` 中的所有故事文件；读取 `production/stage.txt`；报告"发现 4 个故事。当前阶段：[stage]。准备开始 QA 策略？"
2. 第 2 阶段：通过 Task 启动 `qa-lead`；生成策略表，对所有 4 个故事进行分类；未标记阻塞项；向用户展示；AskUserQuestion：用户选择"看起来不错 —— 继续测试计划"
3. 第 3 阶段：生成 QA 计划文档；询问"我可以将 QA 计划写入 `production/qa/qa-plan-sprint-03-[date].md` 吗？"；获得批准后写入
4. 第 4 阶段：通过 Task 启动 `qa-lead`；审查 `tests/smoke/`；返回 PASS；报告"冒烟检查通过。继续测试用例编写。"
5. 第 5 阶段：为每个 Visual/Feel 和 Integration 故事（2–3 个故事）通过 Task 启动 `qa-tester`；并行运行；按故事分组展示测试用例；按组 AskUserQuestion；用户批准
6. 第 6 阶段：逐一遍历每个已批准的故事；用户将所有标记为 PASS；结果摘要："故事 PASS：4，FAIL：0，BLOCKED：0"
7. 第 7 阶段：通过 Task 启动 `qa-lead` 生成签核报告；报告显示所有故事 PASS；未提交 bug；结论：APPROVED；询问"我可以将此 QA 签核报告写入 `production/qa/qa-signoff-sprint-03-[date].md` 吗？"；获得批准后写入
8. 结论：COMPLETE —— QA 周期完成

**断言：**
- [ ] 第 1 阶段正确统计并报告 4 个故事及当前阶段
- [ ] 第 2 阶段的策略表对所有 4 个故事进行了正确分类
- [ ] QA 计划仅在"我可以写入吗？"批准后才写入
- [ ] 冒烟检查 PASS 允许流水线在无需用户干预的情况下继续
- [ ] 第 5 阶段中独立故事的 qa-tester 任务并行发出
- [ ] 签核报告包含测试覆盖范围摘要表和结论：APPROVED
- [ ] 签核报告仅在"我可以写入吗？"批准后才写入
- [ ] 最终输出中出现结论：COMPLETE
- [ ] 下一步："运行 `/gate-check` 以验证进展。"

---

### 用例 2：冒烟检查失败 —— QA 周期在第 4 阶段停止

**前置条件（Fixture）：**
- `production/sprints/sprint-04/` 存在，包含 3 个故事文件
- `tests/smoke/` 存在，包含 5 个冒烟测试项；其中 2 项无法验证（例如，构建不稳定、核心导航损坏）

**输入：** `/team-qa sprint-04`

**预期行为：**
1. 第 1–3 阶段正常完成；QA 计划已写入
2. 第 4 阶段：通过 Task 启动 `qa-lead`；冒烟检查返回 FAIL；识别出两个具体失败项
3. Skill 报告："冒烟检查失败。在这些问题解决之前，QA 无法开始：[列出 2 个失败项]。修复它们并重新运行 `/smoke-check`，或在问题解决后重新运行 `/team-qa`。"
4. Skill 在第 4 阶段后立即停止 —— 不执行第 5、6、7 阶段
5. 不生成签核报告；不发出"我可以写入吗？"的签核请求

**断言：**
- [ ] 冒烟检查 FAIL 导致流水线在第 4 阶段停止 —— 第 5、6、7 阶段不执行
- [ ] 失败列表明确向用户展示（而非模糊概括）
- [ ] Skill 建议将 `/smoke-check` 和重新运行 `/team-qa` 作为补救步骤
- [ ] 不写入或提供 QA 签核报告
- [ ] Skill 不产生 COMPLETE 结论
- [ ] 第 3 阶段已写入的任何 QA 计划被保留（不删除）

---

### 用例 3：发现 Bug —— Visual/Feel 故事手动 QA 失败，提交 bug 报告

**前置条件（Fixture）：**
- `production/sprints/sprint-05/` 存在，包含 2 个故事文件：1 个 Logic（通过自动化测试）、1 个 Visual/Feel
- `tests/smoke/` 冒烟检查通过
- Visual/Feel 故事的动画时间明显错误（未满足验收条件）
- `production/qa/bugs/` 目录存在（为空或包含现有 bug）

**输入：** `/team-qa sprint-05`

**预期行为：**
1. 第 1–5 阶段正常完成；为 Visual/Feel 故事编写了测试用例
2. 第 6 阶段：用户将 Visual/Feel 故事标记为 FAIL；AskUserQuestion 收集失败描述："动画以 2 倍速度播放 —— 每个循环中可见抖动"
3. 第 6 阶段：通过 Task 启动 `qa-tester` 编写正式 bug 报告；bug 报告写入 `production/qa/bugs/BUG-001-animation-speed-jitter.md`（如果存在 bug 则为下一个编号）；报告包含严重性字段
4. 结果摘要："故事 PASS：1，FAIL：1 —— 已提交 bug：BUG-001"
5. 第 7 阶段：启动 `qa-lead` 生成签核报告；已发现 Bug 表列出 BUG-001，附有严重性和状态 Open；结论：NOT APPROVED（S1/S2 bug 未关闭，或 FAIL 无记录在案的工作绕过方案）
6. 提供签核报告写入；获得批准后写入
7. 下一步："解决 S1/S2 bug 并在推进前重新运行 `/team-qa` 或定向手动 QA。"

**断言：**
- [ ] 第 6 阶段的 FAIL 结果触发 AskUserQuestion 在 bug 报告写入前收集失败描述
- [ ] 通过 Task 启动 `qa-tester` 编写 bug 报告 —— 编排器不直接写入
- [ ] Bug 报告遵循命名约定：`BUG-[NNN]-[short-slug].md` 在 `production/qa/bugs/` 中
- [ ] Bug 报告 NNN 根据目录中现有 bug 正确递增
- [ ] 第 7 阶段签核报告已发现 Bug 表包含 bug ID、故事名称、严重性和状态
- [ ] 签核报告中结论为 NOT APPROVED
- [ ] 下一步明确提及重新运行 `/team-qa`
- [ ] 编排器仍然发出结论：COMPLETE（QA 周期已完成 —— 签核结论是 NOT APPROVED，但 skill 完成了其流水线）

---

### 用例 4：无参数 —— Skill 推断当前冲刺或询问用户

**前置条件（变体 A —— 存在状态文件）：**
- `production/session-state/active.md` 存在且包含对 `sprint-06` 的引用
- `production/sprint-status.yaml` 存在且标识 `sprint-06` 为当前活动冲刺

**前置条件（变体 B —— 无状态文件）：**
- `production/session-state/active.md` 不存在
- `production/sprint-status.yaml` 不存在

**输入：** `/team-qa`（无参数）

**预期行为（变体 A）：**
1. 第 1 阶段：未提供参数；读取 `production/session-state/active.md`；读取 `production/sprint-status.yaml`
2. 从两个来源检测到 `sprint-06` 为活动冲刺
3. 如同输入为 `/team-qa sprint-06` 继续执行；报告"未提供冲刺参数 —— 从会话状态推断为 sprint-06。发现 [N] 个故事。"

**预期行为（变体 B）：**
1. 第 1 阶段：未提供参数；尝试读取 `production/session-state/active.md` —— 文件缺失；尝试读取 `production/sprint-status.yaml` —— 文件缺失
2. 无法推断冲刺；使用 AskUserQuestion："QA 应该覆盖哪个冲刺或功能？"并提供输入冲刺标识符或取消的选项

**断言：**
- [ ] 未提供参数时，Skill 不会默认使用硬编码的冲刺名称
- [ ] 在询问用户之前，Skill 同时读取 `production/session-state/active.md` 和 `production/sprint-status.yaml`（变体 A）
- [ ] 当两个状态文件都不存在时，Skill 使用 AskUserQuestion 而非猜测（变体 B）
- [ ] 在继续之前向用户报告推断的冲刺（变体 A 透明度）
- [ ] 状态文件缺失时 Skill 不会报错 —— 它回退到询问用户（变体 B）

---

### 用例 5：混合结果 —— 部分 PASS，一个 FAIL 且带 S1 bug，一个 BLOCKED

**前置条件（Fixture）：**
- `production/sprints/sprint-07/` 存在，包含 4 个故事文件
- 冒烟检查通过
- 故事 A（Logic）：自动化测试通过 —— PASS
- 故事 B（UI）：手动 QA —— PASS WITH NOTES（轻微文本溢出）
- 故事 C（Visual/Feel）：手动 QA —— FAIL；测试人员发现技能激活时出现 S1 崩溃
- 故事 D（Integration）：无法测试 —— BLOCKED（依赖系统尚未实现）

**输入：** `/team-qa sprint-07`

**预期行为：**
1. 第 1–5 阶段继续；第 5 阶段测试用例覆盖故事 B、C、D
2. 第 6 阶段：用户标记故事 A 为隐式 PASS（自动化）；故事 B：PASS WITH NOTES；故事 C：FAIL；故事 D：BLOCKED
3. 故事 C FAIL 后：启动 qa-tester 编写 bug 报告 `BUG-001-crash-ability-activation.md`，严重性为 S1
4. 呈现结果摘要："故事 PASS：1，PASS WITH NOTES：1，FAIL：1 —— 已提交 bug：BUG-001 (S1)，BLOCKED：1"
5. 第 7 阶段：qa-lead 生成签核报告，覆盖全部 4 个故事；BUG-001 列为 S1/Open；故事 D 列为 BLOCKED；结论：NOT APPROVED
6. 在"我可以写入吗？"批准后写入签核报告
7. 下一步："解决 S1/S2 bug 并在推进前重新运行 `/team-qa` 或定向手动 QA。"

**断言：**
- [ ] 所有 4 个故事出现在第 7 阶段签核报告的测试覆盖摘要表中 —— 无故事被静默省略
- [ ] 故事 D（BLOCKED）以 BLOCKED 状态列在报告中，不会被静默丢弃
- [ ] S1 bug 导致结论：NOT APPROVED，无论其他故事是否通过
- [ ] PASS WITH NOTES 故事不会降级为 FAIL —— 它们被单独跟踪
- [ ] BUG-001 严重性在已发现 Bug 表中列为 S1
- [ ] 部分结果被保留 —— 即使存在失败和阻塞，仍生成签核报告
- [ ] 编排器发出结论：COMPLETE（流水线已完成）；签核结论为 NOT APPROVED

---

## 协议合规性

- [ ] 在第 2 阶段（策略审查）、第 5 阶段（按组的测试用例批准）和第 6 阶段（按故事的手动 QA 结果）使用 `AskUserQuestion`
- [ ] 第 4 阶段冒烟检查是硬性关口：FAIL 在第 4 阶段停止流水线，无一例外
- [ ] 分别就 QA 计划（第 3 阶段）和签核报告（第 7 阶段）询问"我可以写入吗？"
- [ ] Bug 报告始终由 `qa-tester` 通过 Task 编写 —— 编排器不直接写入
- [ ] 第 5 阶段中独立故事的 qa-tester 任务尽可能并行发出
- [ ] 错误恢复：任何 BLOCKED 代理立即浮现，并附带 AskUserQuestion 选项
- [ ] 始终产出部分报告 —— 不会因为一个故事失败或阻塞而丢弃任何工作
- [ ] 严格应用签核结论规则：任何未关闭的 S1/S2 bug = NOT APPROVED；无例外
- [ ] 编排器级别的 COMPLETE 结论与签核报告的 APPROVED/NOT APPROVED 结论相互独立

---

## 覆盖说明

- "APPROVED WITH CONDITIONS"结论路径（S3/S4 bug、PASS WITH NOTES）由用例 5 的
  PASS WITH NOTES 故事（故事 B）隐式覆盖 —— 如果不存在 S1/S2 bug，
  该用例将产生 APPROVED WITH CONDITIONS。由于结论逻辑是表驱动的，
  不需要单独的用例。
- `feature: [system-name]` 参数形式未单独测试 —— 它遵循与冲刺形式相同的第 1 阶段
  逻辑，使用 Glob 而非目录读取。无参数推断路径（用例 4）提供了
  检测逻辑的充分覆盖。
- 通过自动化测试的 Logic 故事不需要手动 QA —— 这由用例 5（故事 A）隐式验证，
  其中 Logic 故事未经历手动 QA 阶段。
- 第 5 阶段中并行 qa-tester 启动由用例 1 隐式验证（多个 Visual/Feel 故事
  同时发出）；除静态断言检查外，不需要专门的并行用例。
