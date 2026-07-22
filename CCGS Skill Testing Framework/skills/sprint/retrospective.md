
# 技能测试规格：/retrospective

## 技能概述 (Skill Summary)

`/retrospective` 生成结构化的冲刺 (sprint) 或里程碑 (milestone) 回顾 (retrospective)，涵盖三个类别：做得好、做得不好以及改进措施。它读取冲刺文件和会话日志以编译观察结果，然后生成回顾文档。不使用任何主管门控 (director gate)——回顾是团队自我反思的产物。该技能在持久化之前会询问"我可以写入 `production/retrospectives/retro-sprint-NNN.md` 吗？"。判决 (verdict) 始终为 COMPLETE（完成）（回顾是结构化输出，而非通过/失败评估）。

---

## 静态断言（结构）

由 `/skill-test static` 自动验证——无需测试夹具 (fixture)。

- [ ] 包含所需 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判决关键词：COMPLETE
- [ ] 包含"我可以写入吗"这一类用语（技能会写入回顾文档）
- [ ] 具有下一步交接指引（回顾撰写后该做什么）

---

## 主管门控检查 (Director Gate Checks)

无。回顾是团队自我反思文档；不调用任何门控。

---

## 测试用例 (Test Cases)

### 用例 1：快乐路径——结果多样的冲刺

**测试夹具 (Fixture)：**
- `production/sprints/sprint-005.md` 存在，包含 6 个故事（4 个已完成，1 个受阻，1 个延期）
- `production/session-logs/` 包含该冲刺期间的日志条目
- 之前没有 sprint-005 的回顾

**输入：** `/retrospective sprint-005`

**预期行为：**
1. 技能读取 sprint-005 和会话日志
2. 技能编译三个回顾类别：做得好（交付了 4 个故事）、做得不好（1 个受阻，1 个延期），以及改进措施（解决阻塞根因）
3. 技能向用户展示回顾草稿
4. 技能询问"我可以写入 `production/retrospectives/retro-sprint-005.md` 吗？"
5. 用户批准；文件写入；判决 COMPLETE

**断言 (Assertions)：**
- [ ] 回顾包含全部三个类别（做得好 / 做得不好 / 改进措施）
- [ ] 受阻和延期的故事出现在"做得不好"部分
- [ ] 从受阻故事中至少生成一条改进措施
- [ ] 技能在写入文件前询问"我可以写入吗"
- [ ] 成功写入后判决为 COMPLETE

---

### 用例 2：无冲刺数据——手动输入回退

**测试夹具 (Fixture)：**
- 用户调用 `/retrospective sprint-009`
- `production/sprints/sprint-009.md` 不存在
- 没有会话日志引用 sprint-009

**输入：** `/retrospective sprint-009`

**预期行为：**
1. 技能尝试读取 sprint-009——未找到
2. 技能告知用户未找到 sprint-009 的冲刺数据
3. 技能提示用户手动提供回顾输入（做得好、做得不好、改进措施）
4. 用户提供输入；技能将其格式化为回顾结构
5. 技能询问"我可以写入吗"并在批准后写入文档

**断言：**
- [ ] 当冲刺文件不存在时，技能不会崩溃或生成空文档
- [ ] 提示用户提供手动输入
- [ ] 手动输入被格式化为三类别结构
- [ ] 文件写入前仍出现"我可以写入吗"提示

---

### 用例 3：先前回顾已存在——提供追加或替换选项

**测试夹具 (Fixture)：**
- `production/retrospectives/retro-sprint-005.md` 已存在且有内容
- 用户在变更后重新运行 `/retrospective sprint-005`

**输入：** `/retrospective sprint-005`

**预期行为：**
1. 技能检测到 `retro-sprint-005.md` 已存在
2. 技能向用户提供选择：追加新观察或替换现有文件
3. 用户选择"替换"；技能编译全新回顾
4. 技能询问"我可以写入 `production/retrospectives/retro-sprint-005.md` 吗？"（确认覆盖）
5. 文件被覆盖；判决 COMPLETE

**断言：**
- [ ] 技能在编译前检查现有回顾文件
- [ ] 用户被提供追加或替换选项——不会被静默覆盖
- [ ] "我可以写入吗"提示反映了覆盖场景
- [ ] 无论追加还是替换，写入后判决均为 COMPLETE

---

### 用例 4：边缘情况——来自先前回顾的未解决改进措施

**测试夹具 (Fixture)：**
- `production/retrospectives/retro-sprint-004.md` 存在，包含 2 个标记为 `[ ]`（未完成）的改进措施
- 用户运行 `/retrospective sprint-005`

**输入：** `/retrospective sprint-005`

**预期行为：**
1. 技能读取最近的先前回顾（retro-sprint-004）
2. 技能检测到来自 sprint-004 的 2 个未勾选的改进措施
3. 技能在新的回顾中包含"来自 Sprint 004 的遗留项"部分
4. 未解决的条目被列出，并注明它们未被跟进

**断言：**
- [ ] 技能读取最近的先前回顾以检查未完成的改进措施
- [ ] 未解决的改进措施出现在新回顾的遗留项部分下
- [ ] 遗留项与新生成的改进措施分开显示
- [ ] 输出注明这些条目在之前的冲刺中未被跟进

---

### 用例 5：门控合规——任何模式下均不调用门控

**测试夹具 (Fixture)：**
- `production/sprints/sprint-005.md` 存在，包含已完成故事
- `production/session-state/review-mode.txt` 包含 `full`

**输入：** `/retrospective sprint-005`

**预期行为：**
1. 技能在完整模式下编译回顾
2. 不调用任何主管门控（回顾是团队自我反思，而非交付门控）
3. 技能向用户请求批准，确认后写入文件
4. 判决为 COMPLETE

**断言：**
- [ ] 无论审查模式如何，均不调用主管门控
- [ ] 输出不包含任何门控调用或门控结果标记
- [ ] 技能直接从编译进入"我可以写入吗"提示
- [ ] 审查模式文件内容与本技能的行为无关

---

## 协议合规性 (Protocol Compliance)

- [ ] 在请求写入前始终展示回顾草稿
- [ ] 在写入回顾文件前始终询问"我可以写入吗"
- [ ] 不调用任何主管门控
- [ ] 判决始终为 COMPLETE（非通过/失败类技能）
- [ ] 检查先前回顾中的未解决改进措施

---

## 覆盖范围说明 (Coverage Notes)

- 里程碑回顾（相对于冲刺回顾）遵循相同模式，但读取里程碑文件而非冲刺文件；此处未单独测试。
- 会话日志为空的情况与用例 2（无数据）类似；技能在这两种情况下均回退到手动输入。
