
# 技能测试规格：/story-done

## 技能概述

`/story-done` 关闭设计与实现之间的循环。在实现一个故事结束时运行，
它读取故事文件并验证每个验收标准是否已在实现中得到满足。它检查
GDD 和 ADR 偏差，提示进行代码评审，将故事状态更新为 `Complete`，
记录任何技术债务，并展示冲刺中的下一个就绪故事。它产出
COMPLETE（完成）/ COMPLETE WITH NOTES（附带说明完成）/ BLOCKED（阻塞）
判定，并写入故事文件以及可选的 `docs/tech-debt-register.md`。

---

## 静态断言（结构检查）

由 `/skill-test static` 自动验证 — 无需测试夹具。

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥5 个阶段标题（复杂技能，如适用则需 `context: fork`）
- [ ] 包含判定关键词：COMPLETE、BLOCKED
- [ ] 包含"May I write"协作协议语言（写入故事文件和技术债务登记表）
- [ ] 具有下一步交接（展示冲刺中的下一个故事）

---

## 测试用例

### 用例 1：正常路径 — 所有验收标准均满足，无偏差

**测试夹具：**
- 故事文件位于 `production/epics/core/story-light-pickup.md`，包含：
  - 3 个验收标准，均按描述实现
  - `TR-ID: TR-light-001`，引用一个 GDD 需求
  - `ADR: docs/architecture/adr-003-inventory.md`（已接受）
  - `Status: In Progress`
- 故事中列出的实现文件存在于 `src/`
- TR-light-001 处的 GDD 需求文本与功能的实现方式一致
- ADR 指引已被遵循（无偏差）

**输入：** `/story-done production/epics/core/story-light-pickup.md`

**预期行为：**
1. 技能读取故事文件并提取所有关键字段
2. 技能从 `tr-registry.yaml`（而非故事中引用的文本）重新读取 GDD 需求
3. 技能读取引用的 ADR 以了解实现约束
4. 技能评估每个验收标准（尽可能自动，必要时手动提示）
5. 技能检查 GDD 需求偏差
6. 技能检查 ADR 指南偏差
7. 技能提示用户："请提供此故事的代码评审结果"
8. 技能展示 COMPLETE 判定
9. 技能询问"May I update story Status to Complete and add Completion Notes？"
10. 如果是：技能更新故事文件
11. 技能从冲刺中展示下一个"Ready for Dev"故事

**断言：**
- [ ] 技能读取 `docs/architecture/tr-registry.yaml` 以获取 TR-ID 需求文本（不仅限于故事）
- [ ] 技能读取引用的 ADR 文件（不仅限于故事中的引用）
- [ ] 每个验收标准以 VERIFIED（已验证）/ DEFERRED（推迟）/ FAILED（失败）状态列出
- [ ] 技能提示用户提供代码评审结果（不跳过此步骤）
- [ ] 当所有标准已验证且无偏差时，判定为 COMPLETE
- [ ] 在更新故事文件前，技能询问"May I write"
- [ ] 未经用户确认，技能不会自动更新故事状态
- [ ] 完成后，技能从 `production/sprints/` 中展示下一个就绪故事

---

### 用例 2：阻塞路径 — 验收标准无法验证

**测试夹具：**
- 故事文件包含验收标准："玩家在拾取时看到正确的动画"
- 此标准不存在自动化测试
- 手动验证尚未执行
- 所有其他标准均已满足

**输入：** `/story-done production/epics/core/story-light-pickup.md`

**预期行为：**
1. 技能处理所有验收标准
2. 到达动画标准——无法自动验证
3. 技能询问用户："验收标准'玩家在拾取时看到正确的动画'无法自动验证。是否已手动测试？"
4. 如果用户说"否"：标准标记为 DEFERRED，判定变为 COMPLETE WITH NOTES
5. 技能在完成说明中记录推迟的标准
6. 询问"May I write updated story with deferred criterion noted？"

**断言：**
- [ ] 技能询问用户关于无法验证的标准，而不是假定为 PASS
- [ ] 推迟的标准导致 COMPLETE WITH NOTES（而非 COMPLETE 或 BLOCKED）
- [ ] 推迟的标准在完成说明中被明确命名
- [ ] 在更新故事文件前，技能仍询问"May I write"

---

### 用例 3：阻塞路径 — 检测到 GDD 偏差

**测试夹具：**
- 故事 TR-ID 指向需求："玩家最多可携带 3 个光源"
- `src/` 中的实现使用变量 `MAX_CARRIED_LIGHTS = 5`
- 这是与 GDD 有意的偏差

**输入：** `/story-done production/epics/core/story-light-pickup.md`

**预期行为：**
1. 技能读取 GDD 需求文本（最多 3 个）
2. 技能检测到需求与实现值（5）之间的差异
3. 技能将此标记为 GDD 偏差，并要求用户分类：
   - INTENTIONAL（有意）：记录偏差及原因
   - ERROR（错误）：实现须在故事标记为完成前修复
   - OUT OF SCOPE（超出范围）：需求已变更，GDD 需要更新
4. 如果为 INTENTIONAL：技能在完成说明中记录偏差，判定为 COMPLETE WITH NOTES
5. 如果为 ERROR：判定为 BLOCKED，直至实现被纠正

**断言：**
- [ ] 技能检测到 GDD 需求与实现值之间的不匹配
- [ ] 技能要求用户对偏差进行分类（不自行假定归属）
- [ ] INTENTIONAL 偏差 → COMPLETE WITH NOTES（而非 BLOCKED）
- [ ] ERROR 偏差 → BLOCKED 判定，直至修复
- [ ] 检测到的偏差记录在完成说明或技术债务登记表中

---

### 用例 4：边界情况 — 无参数，自动检测当前故事

**测试夹具：**
- `production/session-state/active.md` 包含对 `production/epics/core/story-oxygen-drain.md` 的引用，作为当前活跃故事
- 该故事文件存在，状态为 `Status: In Progress`

**输入：** `/story-done`（无参数）

**预期行为：**
1. 技能读取 `production/session-state/active.md`
2. 技能找到当前故事引用
3. 技能读取该故事文件并正常进行
4. 输出确认自动检测到哪个故事

**断言：**
- [ ] 未提供参数时，技能读取 `production/session-state/active.md`
- [ ] 技能识别并确认自动检测到的故事，然后再继续
- [ ] 如果会话状态中未找到故事，技能要求用户提供路径

---

### 用例 5：总监关卡 — LP-CODE-REVIEW 在不同评审模式下的行为

**测试夹具：**
- 故事文件位于 `production/epics/core/story-light-pickup.md`
- 所有验收标准已验证，无 GDD 偏差
- `production/session-state/review-mode.txt` 存在

**用例 5a — full 模式：**
- `review-mode.txt` 内容为 `full`

**输入：** `/story-done production/epics/core/story-light-pickup.md`（full 模式）

**预期行为：**
1. 技能读取评审模式 — 确定为 `full`
2. 实现验证完成后，技能调用 LP-CODE-REVIEW 关卡
3. 首席程序员评审实现
4. 如果 LP 判定为 NEEDS CHANGES → 故事不能标记为 Complete
5. 如果 LP 判定为 APPROVED → 技能继续标记故事为 Complete

**断言（5a）：**
- [ ] 技能在决定是否调用 LP-CODE-REVIEW 之前读取评审模式
- [ ] full 模式下，在实现检查完成后调用 LP-CODE-REVIEW 关卡
- [ ] LP 的 NEEDS CHANGES 判定阻止故事被标记为 Complete
- [ ] 关卡结果记录在输出中："Gate: LP-CODE-REVIEW — [result]"
- [ ] 即使 LP 批准，技能在更新故事状态前仍需询问"May I write"

**用例 5b — lean 或 solo 模式：**
- `review-mode.txt` 内容为 `lean` 或 `solo`

**预期行为：**
1. 技能读取评审模式 — 确定为 `lean` 或 `solo`
2. LP-CODE-REVIEW 关卡被跳过
3. 输出注明跳过："[LP-CODE-REVIEW] skipped — Lean/Solo mode"
4. 故事完成仅基于验收标准检查进行

**断言（5b）：**
- [ ] lean 或 solo 模式下不生成 LP-CODE-REVIEW 关卡
- [ ] 跳过操作在输出中有明确注明
- [ ] 在标记故事为 Complete 之前，技能仍需要"May I write"批准

---

## 协议合规性

- [ ] 在更新故事文件前使用"May I write"
- [ ] 在向 `docs/tech-debt-register.md` 添加条目前使用"May I write"
- [ ] 在请求批准前展示完整发现（标准检查、偏差检查）
- [ ] 以从冲刺计划中展示下一个就绪故事结尾
- [ ] 如果有任何标准处于 ERROR 状态，不将故事标记为 Complete
- [ ] 不跳过代码评审提示

---

## 覆盖说明

- 该技能的完整 8 阶段流程通过用例 1-3 进行了演练；并非每个阶段内的所有边缘情况都被覆盖。
- 技术债务记录（推迟项写入 `docs/tech-debt-register.md`）在用例 2 中提到，但不是主要的断言关注点；专门的覆盖已推迟。
- `sprint-status.yaml` 更新（技能中的阶段 7）由用例 1 隐含，但不是主要断言；假定遵循相同的"May I write"模式。
- 具有多个 TR-ID 或多个 ADR 的故事未被明确测试。
