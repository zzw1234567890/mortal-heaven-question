
# 技能测试规范：/story-readiness

## 技能概述

`/story-readiness` 用于验证一个 story 文件是否已达到开发者可以接手
实现的就绪状态。它检查四个维度：设计（内嵌的 GDD 需求）、架构（ADR
引用及其状态）、范围（边界清晰、DoD 明确）以及完成定义（Definition of
Done，可测试的标准）。它产出 READY / NEEDS WORK / BLOCKED 判定结果。
该技能为只读技能，在开发者接手 story 之前运行。

---

## 静态断言（结构检查）

由 `/skill-test static` 自动验证 — 无需测试夹具。

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题或编号检查章节
- [ ] 包含判定关键词：READY、NEEDS WORK、BLOCKED
- [ ] 不要求 "May I write" 措辞（只读技能）
- [ ] 具有后续步骤交接（判定之后该做什么）

---

## 测试用例

### 用例 1：正常路径 — 完全就绪的 story

**测试夹具：**
- Story 文件位于 `production/epics/core/story-light-pickup.md`
- Story 包含：
  - `TR-ID: TR-light-001`（GDD 需求引用）
  - `ADR: docs/architecture/adr-003-inventory.md`
  - 被引用的 ADR 存在且状态为 `Accepted`
  - 被引用的 TR-ID 存在于 `docs/architecture/tr-registry.yaml`
  - Story 具有 `## Acceptance Criteria`，且包含 ≥3 个可测试条目
  - Story 具有 `## Definition of Done` 章节
  - Story 具有 `Status: Ready for Dev`
  - Story 头部中的 manifest 版本与当前 `docs/architecture/control-manifest.md` 一致

**输入：** `/story-readiness production/epics/core/story-light-pickup.md`

**预期行为：**
1. 技能读取 story 文件
2. 技能读取被引用的 ADR — 验证状态为 `Accepted`
3. 技能读取 `docs/architecture/tr-registry.yaml` — 验证 TR-ID 存在
4. 技能读取 `docs/architecture/control-manifest.md` — 验证 manifest 版本一致
5. 技能评估全部 4 个维度（设计、架构、范围、DoD）
6. 技能输出 READY 判定，所有检查通过

**断言：**
- [ ] 技能读取了被引用的 ADR 文件（而不只是 story）
- [ ] 技能验证 ADR 状态为 `Accepted`（而非 `Proposed`）
- [ ] 技能读取 `tr-registry.yaml` 以验证 TR-ID 存在
- [ ] 输出包含全部 4 个维度的检查结果
- [ ] 所有检查通过时判定为 READY
- [ ] 技能不写入任何文件

---

### 用例 2：阻塞路径 — 被引用的 ADR 为 Proposed（非 Accepted）

**测试夹具：**
- Story 文件存在，含 `ADR: docs/architecture/adr-005-light-system.md`
- `adr-005-light-system.md` 存在但状态为 `Status: Proposed`
- Story 其余内容完整

**输入：** `/story-readiness production/epics/core/story-light-system.md`

**预期行为：**
1. 技能读取 story
2. 技能读取 `adr-005-light-system.md` — 发现 `Status: Proposed`
3. 技能将其标记为阻塞性问题（不能基于未被接受的 ADR 进行实现）
4. 技能输出 BLOCKED 判定
5. 技能建议：先接受或否决该 ADR，然后再接手 story

**断言：**
- [ ] ADR 为 Proposed 时判定为 BLOCKED（而非 NEEDS WORK 或 READY）
- [ ] 输出明确指出该 Proposed ADR 是阻塞原因
- [ ] 输出建议先解决 ADR 状态再继续
- [ ] 即使其他检查全部通过，技能也不输出 READY

---

### 用例 3：需要完善 — 缺少验收标准

**测试夹具：**
- Story 文件存在但没有 `## Acceptance Criteria` 章节
- ADR 引用存在且为 `Accepted`
- TR-ID 存在于注册表中
- Manifest 版本一致

**输入：** `/story-readiness production/epics/core/story-oxygen-drain.md`

**预期行为：**
1. 技能读取 story
2. 技能发现缺少 Acceptance Criteria 章节
3. 技能将其标记为 NEEDS WORK 问题（story 不完整，但未阻塞）
4. 技能输出 NEEDS WORK 判定
5. 技能指出缺失的章节，并建议补充可衡量的标准

**断言：**
- [ ] 缺少 Acceptance Criteria 章节时判定为 NEEDS WORK（而非 BLOCKED 或 READY）
- [ ] 输出明确指出缺失的是 Acceptance Criteria 章节
- [ ] 输出建议添加可测试/可衡量的标准
- [ ] 技能能区分 NEEDS WORK（无需外部依赖即可修复）与 BLOCKED（需要外部行动）

---

### 用例 4：边界情况 — manifest 版本过期

**测试夹具：**
- Story 文件头部含 `Manifest Version: 2026-01-15`
- `docs/architecture/control-manifest.md` 含 `Manifest Version: 2026-03-10`
- 版本不一致（story 创建早于 manifest 更新）

**输入：** `/story-readiness production/epics/core/story-mirror-rotation.md`

**预期行为：**
1. 技能读取 story 并提取 manifest 版本 `2026-01-15`
2. 技能读取 control manifest 头部并提取当前版本 `2026-03-10`
3. 技能检测到版本不一致
4. 技能将其标记为提示性问题（不阻塞，但值得注意）
5. 判定为 NEEDS WORK，并注明 manifest 过期

**断言：**
- [ ] 技能读取 `docs/architecture/control-manifest.md` 以获取当前版本
- [ ] 技能将 story 内嵌的 manifest 版本与当前 manifest 版本进行比较
- [ ] 过期的 manifest 版本导致 NEEDS WORK（而非 BLOCKED，也非 READY）
- [ ] 输出说明 story 内嵌的指引可能已过时

---

### 用例 5：总监关卡 — QL-STORY-READY 在不同评审模式下的行为

**测试夹具：**
- Story 文件存在且已 READY（4 个维度全部通过、ADR 已 Accepted、标准齐全）
- `production/session-state/review-mode.txt` 存在

**用例 5a — full 模式：**
- `review-mode.txt` 内容为 `full`

**输入：** `/story-readiness production/epics/core/story-light-pickup.md`（full 模式）

**预期行为：**
1. 技能读取评审模式 — 判定为 `full`
2. 完成自身的 4 维度检查后，技能调用 QL-STORY-READY 关卡
3. QA lead 评审该 story 的就绪程度
4. 若 QA lead 判定为 INADEQUATE → 无论 4 维度结果如何，story 判定为 BLOCKED
5. 若 QA lead 判定为 ADEQUATE → 判定正常进行

**断言（5a）：**
- [ ] 技能在决定是否调用 QL-STORY-READY 之前读取评审模式
- [ ] full 模式下，在 4 维度检查完成后调用 QL-STORY-READY 关卡
- [ ] QA lead 的 INADEQUATE 判定会覆盖 READY 的 4 维度结果 → 最终判定 BLOCKED
- [ ] 关卡调用在输出中有记录："Gate: QL-STORY-READY — [result]"

**用例 5b — lean 或 solo 模式：**
- `review-mode.txt` 内容为 `lean` 或 `solo`

**预期行为：**
1. 技能读取评审模式 — 判定为 `lean` 或 `solo`
2. 跳过 QL-STORY-READY 关卡
3. 输出注明跳过："[QL-STORY-READY] skipped — Lean/Solo mode"
4. 判定仅基于 4 维度检查

**断言（5b）：**
- [ ] lean 或 solo 模式下不派生 QL-STORY-READY 关卡
- [ ] 跳过在输出中有明确注明
- [ ] 判定仅基于 4 维度检查

---

## 协议合规性

- [ ] 不使用 Write 或 Edit 工具（只读技能）
- [ ] 在给出判定之前先展示完整检查结果
- [ ] 不要求批准（无文件写入）
- [ ] 以推荐的后续步骤结尾（修复问题或进入实现）
- [ ] 清晰区分三个判定级别（READY vs NEEDS WORK vs BLOCKED）

---

## 覆盖说明

- TR-ID 完全不存在于注册表中的情况未在此显式测试；其处理方式
  与用例 3 的 NEEDS WORK 模式相同。
- "无参数" 路径（技能自动检测当前 story）未测试，因为它依赖
  `production/session-state/active.md` 的内容，难以可靠地构造夹具。
- 具有多个 ADR 引用的 story 未测试；假定行为是可叠加的（所有 ADR
  必须为 Accepted 才能判定 READY）。
