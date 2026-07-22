# 技能测试规格：/brainstorm


## 技能概述 (Skill Summary)

`/brainstorm` 引导游戏概念创意构思。它呈现 2-4 个概念选项及其优缺点，让用户选择并优化一个概念，然后生成结构化的 `design/gdd/game-concept.md` 文档。该技能是协作式的——在提出选项之前会先提问，并持续迭代直到用户批准概念方向。

在 `full` 审查模式下，概念草稿完成后会并行生成四个总监关卡 (director gates)：CD-PILLARS (creative-director)、AD-CONCEPT-VISUAL (art-director)、TD-FEASIBILITY (technical-director) 和 PR-SCOPE (producer)。在 `lean` 模式下，所有 4 个内联关卡均被跳过（lean 模式仅运行 PHASE-GATE，而 brainstorm 没有此类关卡）。在 `solo` 模式下，所有关卡均被跳过。技能在写入 `design/gdd/game-concept.md` 之前会询问"May I write"。

---

## 静态断言 (Structural)

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 拥有必需的前置元字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 有 ≥2 个阶段标题
- [ ] 包含裁决关键词：APPROVED、REJECTED、CONCERNS
- [ ] 包含"May I write"协作协议语言（针对 game-concept.md）
- [ ] 末尾有下一步交接（`/map-systems`）
- [ ] 在 full 模式下记录了 4 个总监关卡：CD-PILLARS、AD-CONCEPT-VISUAL、TD-FEASIBILITY、PR-SCOPE
- [ ] 记录了所有 4 个关卡在 lean 和 solo 模式下均被跳过

---

## 总监关卡检查 (Director Gate Checks)

在 `full` 模式下：用户批准概念草稿后，CD-PILLARS、AD-CONCEPT-VISUAL、TD-FEASIBILITY 和 PR-SCOPE 并行生成。

在 `lean` 模式下：所有 4 个内联关卡均被跳过（brainstorm 没有 PHASE-GATE，因此 lean 模式跳过所有内容）。输出中标注所有 4 个为："[GATE-ID] 已跳过——lean 模式"。

在 `solo` 模式下：所有 4 个关卡均被跳过。输出中标注所有 4 个为："[GATE-ID] 已跳过——solo 模式"。

---

## 测试用例 (Test Cases)

### 用例 1：正常路径 (Happy Path) —— Full 模式，3 个概念，用户选择一个，所有 4 位总监批准

**测试夹具：**
- 不存在现有的 `design/gdd/game-concept.md`
- `production/session-state/review-mode.txt` 内容为 `full`

**输入：** `/brainstorm`

**预期行为：**
1. 技能向用户询问关于游戏类型、范围和目标感受的问题
2. 技能呈现 3 个概念选项，每个附带优缺点
3. 用户选择一个概念
4. 技能将所选概念展开为结构化的草稿
5. 所有 4 个总监关卡并行生成：CD-PILLARS、AD-CONCEPT-VISUAL、TD-FEASIBILITY、PR-SCOPE
6. 所有 4 个均返回 APPROVED
7. 技能询问"是否可以写入 `design/gdd/game-concept.md`？"
8. 批准后写入概念

**断言：**
- [ ] 恰好呈现 3 个概念选项（不是 1 个，不是 5 个以上）
- [ ] 所有 4 个总监关卡并行生成（非顺序执行）
- [ ] 所有 4 个关卡在"May I write"询问之前完成
- [ ] 在写入之前询问"是否可以写入 `design/gdd/game-concept.md`？"
- [ ] 未经用户批准不写入概念文件
- [ ] 存在下一步交接至 `/map-systems`

---

### 用例 2：失败路径 (Failure Path) —— CD-PILLARS 返回 REJECT

**测试夹具：**
- 概念草稿已完成
- `production/session-state/review-mode.txt` 内容为 `full`
- CD-PILLARS 关卡返回 REJECT："该概念没有可识别的创意支柱"

**输入：** `/brainstorm`

**预期行为：**
1. CD-PILLARS 关卡返回 REJECT 并附具体反馈
2. 技能将拒绝信息呈现给用户
3. 概念不被写入文件
4. 询问用户：重新思考概念方向，或覆盖拒绝决定
5. 如果选择重新思考：技能返回到概念选项阶段

**断言：**
- [ ] 当 CD-PILLARS 返回 REJECT 时，概念不被写入
- [ ] 拒绝反馈按原样显示给用户
- [ ] 用户可以选择重新思考或覆盖
- [ ] 如果用户选择重新思考，技能返回到概念构思阶段

---

### 用例 3：Lean 模式 (Lean Mode) —— 所有 4 个关卡均跳过；用户确认后写入概念

**测试夹具：**
- 不存在现有的游戏概念
- `production/session-state/review-mode.txt` 内容为 `lean`

**输入：** `/brainstorm`

**预期行为：**
1. 呈现概念选项，用户选择一个
2. 概念展开为结构化草稿
3. 所有 4 个总监关卡均被跳过——每个标注："[GATE-ID] 已跳过——lean 模式"
4. 技能要求用户确认概念已准备好写入
5. 确认后询问"是否可以写入 `design/gdd/game-concept.md`？"
6. 批准后写入概念

**断言：**
- [ ] 所有 4 个关卡跳过注释出现："CD-PILLARS 已跳过——lean 模式"、"AD-CONCEPT-VISUAL 已跳过——lean 模式"、"TD-FEASIBILITY 已跳过——lean 模式"、"PR-SCOPE 已跳过——lean 模式"
- [ ] 仅在用户确认后写入概念（在 lean 模式下无需总监批准）
- [ ] 写入前仍然询问"May I write"

---

### 用例 4：Solo 模式 (Solo Mode) —— 所有关卡均跳过；仅需用户批准即写入概念

**测试夹具：**
- 不存在现有的游戏概念
- `production/session-state/review-mode.txt` 内容为 `solo`

**输入：** `/brainstorm`

**预期行为：**
1. 呈现概念选项，用户选择一个
2. 概念草稿展示给用户
3. 所有 4 个总监关卡均被跳过——每个标注" solo 模式"
4. 询问"是否可以写入 `design/gdd/game-concept.md`？"
5. 用户批准后写入概念

**断言：**
- [ ] 所有 4 个跳过注释出现，带有"solo 模式"标签
- [ ] 未生成任何总监代理
- [ ] 仅需用户批准即写入概念
- [ ] 对于此技能，其他行为与 lean 模式等效

---

### 用例 5：总监关卡 (Director Gate) —— PR-SCOPE 返回 CONCERNS（范围过大）

**测试夹具：**
- 概念草稿已完成
- `production/session-state/review-mode.txt` 内容为 `full`
- PR-SCOPE 关卡返回 CONCERNS："该概念范围需要独立开发者 18 个月以上的时间"

**输入：** `/brainstorm`

**预期行为：**
1. PR-SCOPE 关卡返回 CONCERNS 并附具体范围反馈
2. 技能将范围问题呈现给用户
3. 范围问题在写入前记录到概念草稿中
4. 询问用户：缩小范围、接受问题并记录、或重新思考
5. 如果接受问题：概念写入时嵌入"范围风险 (Scope Risk)"说明

**断言：**
- [ ] PR-SCOPE 的问题在"May I write"询问之前展示给用户
- [ ] 技能不会在不呈现范围问题的情况下写入概念
- [ ] 如果用户接受：范围问题记录在概念文件中
- [ ] 技能不会因 PR-SCOPE 的 CONCERNS 而自动拒绝概念（由用户决定）

---

## 协议合规性 (Protocol Compliance)

- [ ] 在用户承诺之前呈现 2-4 个概念选项及其优缺点
- [ ] 在调用总监关卡之前用户确认概念方向
- [ ] 在 full 模式下所有 4 个总监关卡并行生成
- [ ] 在 lean 和 solo 模式下所有 4 个关卡均被跳过——每个按名称标注
- [ ] 在写入之前询问"是否可以写入 `design/gdd/game-concept.md`？"
- [ ] 以下一步交接结束：`/map-systems`

---

## 覆盖说明 (Coverage Notes)

- AD-CONCEPT-VISUAL 关卡（艺术总监可行性）与其他 3 个关卡一起在并行生成中分组——未独立进行夹具测试。
- 迭代概念优化循环（用户拒绝所有选项，技能生成新的）未进行夹具测试——它遵循与选项选择阶段相同的模式。
- game-concept.md 文档结构（必需部分）在技能主体中定义，不在测试断言中重新列举。
