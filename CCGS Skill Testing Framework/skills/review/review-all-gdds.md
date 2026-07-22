
# 技能测试规格：/review-all-gdds

## 技能概述 (Skill Summary)

`/review-all-gdds` 是一个 Opus 层级 (Opus-tier) 的技能，对 `design/gdd/` 中的所有文件执行全面跨 GDD 审查。它并行运行两个互补的审查阶段：第一阶段检查一致性（矛盾、公式不匹配、过期引用、所有权冲突），第二阶段检查设计理论（主导策略、支柱偏离、认知过载、经济失衡)。由于这两个阶段相互独立，它们同时启动以节省时间。该技能产出以下判决 (verdict)：CONSISTENT（一致）、MINOR ISSUES（轻微问题）或 MAJOR ISSUES（重大问题），且为只读——未经用户明确批准不写入任何文件。

该技能本身就是流水线中的全面审查门控。它在各个 GDD 完成后、架构工作开始前被调用。它不启动任何主管门控智能体（它本身即是主管级别的审查）。

---

## 静态断言（结构）

由 `/skill-test static` 自动验证——无需测试夹具 (fixture)。

- [ ] 包含所需 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥5 个阶段标题（复杂多阶段技能）
- [ ] 包含判决关键词：CONSISTENT、MINOR ISSUES、MAJOR ISSUES
- [ ] 不要求"我可以写入吗"这一类用语（只读技能）
- [ ] 末尾包含下一步交接指引
- [ ] 记录了并行阶段启动（第一阶段和第二阶段的独立性）

---

## 主管门控检查 (Director Gate Checks)

无主管门控——本技能不启动任何主管门控智能体。它本身就是全面审查；委托给主管门控将造成循环依赖。

---

## 测试用例 (Test Cases)

### 用例 1：快乐路径——无冲突的干净 GDD 集合

**测试夹具 (Fixture)：**
- `design/gdd/` 包含 ≥3 个系统 GDD
- 所有 GDD 在内部保持一致：无公式矛盾、无所有权冲突、无过期引用
- 所有 GDD 均与 `design/gdd/game-pillars.md` 中定义的游戏支柱保持一致

**输入：** `/review-all-gdds`

**预期行为：**
1. 技能读取 `design/gdd/` 中的所有 GDD 文件
2. 第一阶段（一致性扫描）和第二阶段（设计理论检查）并行启动
3. 第一阶段未发现矛盾、公式不匹配或所有权冲突
4. 第二阶段未发现支柱偏离、主导策略或认知过载
5. 技能输出结构化问题表格，0 个阻塞性问题
6. 判决：CONSISTENT

**断言 (Assertions)：**
- [ ] 两个审查阶段并行启动（非顺序）
- [ ] 输出包含问题表格（即使为空——显示"未发现问题"）
- [ ] 未发现冲突时判决为 CONSISTENT
- [ ] 未经用户批准，技能不写入任何文件
- [ ] 包含指向 `/architecture-review` 或 `/create-architecture` 的下一步交接指引

---

### 用例 2：失败路径——两个 GDD 之间存在冲突规则

**测试夹具 (Fixture)：**
- GDD-A 定义了一个下限值（例如，"最低 [输出] 为 [N]"）
- GDD-B 声明了一种可以绕过该下限的机制（例如，"[机制] 可以将 [输出] 降至 0"）
- 两个 GDD 在其他方面完整且有效

**输入：** `/review-all-gdds`

**预期行为：**
1. 第一阶段（一致性扫描）检测到 GDD-A 与 GDD-B 之间的矛盾
2. 报告冲突时包含：两个文件名、具体的冲突规则及严重程度 HIGH
3. 判决：MAJOR ISSUES
4. 交接指引指示用户解决冲突并重新运行，然后再继续

**断言：**
- [ ] 判决为 MAJOR ISSUES（非 CONSISTENT 或 MINOR ISSUES）
- [ ] 冲突条目中同时包含两个 GDD 的文件名
- [ ] 引用或描述了具体的冲突规则（而非模糊的"发现冲突"）
- [ ] 问题被分类为严重程度 HIGH（阻塞性）
- [ ] 技能不会自动解决冲突

---

### 用例 3：部分路径——单一 GDD 存在孤立依赖引用

**测试夹具 (Fixture)：**
- GDD-A 在其依赖关系 (Dependencies) 部分列出了一个指向"system-B"的依赖
- `design/gdd/` 中不存在 system-B 的 GDD
- 所有其他 GDD 均一致

**输入：** `/review-all-gdds`

**预期行为：**
1. 第一阶段检测到 GDD-A 中的孤立依赖引用
2. 问题报告为：DEPENDENCY GAP（依赖缺口）——GDD-A 引用了 system-B，但该系统没有对应的 GDD
3. 未发现其他冲突
4. 判决：MINOR ISSUES（依赖缺口是建议性的，本身不构成阻塞）

**断言：**
- [ ] 对于单一孤立引用，判决为 MINOR ISSUES（非 MAJOR ISSUES）
- [ ] 报告了具体的 GDD 文件名和缺失的依赖名称
- [ ] 技能建议运行 `/design-system system-B` 以解决缺口
- [ ] 技能不会跳过或静默忽略缺失的依赖

---

### 用例 4：边缘情况——未找到 GDD 文件

**测试夹具 (Fixture)：**
- `design/gdd/` 目录为空或不存在
- 没有任何 GDD 文件

**输入：** `/review-all-gdds`

**预期行为：**
1. 技能尝试读取 `design/gdd/` 中的文件
2. 未找到文件——技能输出错误信息并附上指导
3. 技能建议在重新运行前先运行 `/brainstorm` 和 `/design-system`
4. 技能不产出判决（CONSISTENT / MINOR ISSUES / MAJOR ISSUES）

**断言：**
- [ ] 当未找到 GDD 时，技能输出明确的错误信息
- [ ] 目录为空时不产出判决
- [ ] 技能推荐正确的下一步操作（`/brainstorm` 或 `/design-system`）
- [ ] 技能不会崩溃或产出部分报告

---

### 用例 5：主管门控——无论审查模式如何，均不启动门控

**测试夹具 (Fixture)：**
- `design/gdd/` 包含 ≥2 个一致的系统 GDD
- `production/session-state/review-mode.txt` 存在，内容为 `full`

**输入：** `/review-all-gdds`

**预期行为：**
1. 技能读取所有 GDD 并运行两个审查阶段
2. 技能不读取 `review-mode.txt`
3. 技能不启动任何主管门控智能体（CD-、TD-、PR-、AD- 前缀）
4. 技能正常完成并输出其判决
5. 审查模式设置对本技能的行为没有任何影响

**断言：**
- [ ] 任何时候均不启动主管门控智能体
- [ ] 技能不读取 `production/session-state/review-mode.txt`
- [ ] 输出不包含任何"门控：[GATE-ID]"或"已跳过"的门控条目
- [ ] 无论审查模式如何，技能均产出判决
- [ ] R4 度量：本技能在所有模式下的门控数 = 0

---

## 协议合规性 (Protocol Compliance)

- [ ] 第一阶段（一致性）和第二阶段（设计理论）并行启动——非顺序
- [ ] 未经"我可以写入吗"批准，不写入任何文件
- [ ] 在任何写入请求之前先展示问题表格
- [ ] 判决严格为以下三者之一：CONSISTENT、MINOR ISSUES、MAJOR ISSUES
- [ ] 末尾提供适当的交接指引：MAJOR ISSUES → 修复并重新运行；MINOR ISSUES → 可带着意识继续；CONSISTENT → `/create-architecture`

---

## 覆盖范围说明 (Coverage Notes)

- 经济平衡分析（产出/消耗循环）需要跨 GDD 的资源数据——结构上由用例 2 覆盖（冲突检测模式相同）。
- 设计理论阶段（第二阶段）的检查，包括主导策略检测和认知过载，未作为独立测试夹具进行测试——它们遵循与一致性检查相同的模式，并通过支柱偏离案例结构进行验证。
- `since-last-review`（自上次审查以来）范围限定模式在此处不测试——它是一个运行时关注点。
