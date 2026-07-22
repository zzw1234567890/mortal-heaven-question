
# 技能测试规格：/architecture-review

## 技能概述 (Skill Summary)

`/architecture-review` 是一个 Opus 层级 (Opus-tier) 的技能，用于验证技术架构文档是否满足项目要求的 8 个架构章节，并检查其内部一致性、与现有 ADR 无矛盾，以及是否正确针对锁定的引擎版本。它产出以下判决 (verdict)：APPROVED（通过）、NEEDS REVISION（需修订）或 MAJOR REVISION NEEDED（需重大修订）。

在 `full`（完整）审查模式下，该技能会并行启动两个主管门控 (director gate) 智能体：TD-ARCHITECTURE (technical-director，技术总监) 和 LP-FEASIBILITY (lead-programmer，主程)。在 `lean`（精简）或 `solo`（单人）模式下，两个门控均被跳过并予以注明。该技能为只读——不写入任何文件。

---

## 静态断言（结构）

由 `/skill-test static` 自动验证——无需测试夹具 (fixture)。

- [ ] 包含所需 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判决关键词：APPROVED、NEEDS REVISION、MAJOR REVISION NEEDED
- [ ] 不要求"我可以写入吗"这一类用语（只读技能）
- [ ] 末尾包含下一步交接指引
- [ ] 记录了门控行为：完整模式下为 TD-ARCHITECTURE + LP-FEASIBILITY；精简/单人模式下跳过

---

## 主管门控检查 (Director Gate Checks)

在 `full`（完整）模式下：TD-ARCHITECTURE (technical-director，技术总监) 和 LP-FEASIBILITY (lead-programmer，主程) 在技能读取架构文档后并行启动。

在 `lean`（精简）模式下：两个门控均被跳过。输出注明：
"TD-ARCHITECTURE 已跳过——精简模式"和"LP-FEASIBILITY 已跳过——精简模式"。

在 `solo`（单人）模式下：两个门控均被跳过，并附有类似说明。

---

## 测试用例 (Test Cases)

### 用例 1：快乐路径——完整架构文档，完整模式

**测试夹具 (Fixture)：**
- `docs/architecture/architecture.md` 存在，且全部 8 个必需章节均已填充内容
- 所有章节均引用 `docs/engine-reference/` 中的正确引擎版本
- 与 `docs/architecture/` 中已有的已接受 (Accepted) ADR 无矛盾
- `production/session-state/review-mode.txt` 包含 `full`

**输入：** `/architecture-review docs/architecture/architecture.md`

**预期行为：**
1. 技能读取架构文档
2. 技能读取现有 ADR 进行交叉引用
3. 技能读取引擎版本参考
4. TD-ARCHITECTURE 和 LP-FEASIBILITY 门控智能体并行启动
5. 两个门控均返回 APPROVED
6. 技能输出逐章节完整性检查（8/8 章节均存在）
7. 判决：APPROVED

**断言 (Assertions)：**
- [ ] 所有 8 个必需章节均被检查并报告
- [ ] TD-ARCHITECTURE 和 LP-FEASIBILITY 并行启动（非顺序）
- [ ] 当所有章节均存在且无冲突时，判决为 APPROVED
- [ ] 技能不写入任何文件
- [ ] 包含指向 `/create-control-manifest` 或 `/create-epics` 的下一步交接指引

---

### 用例 2：失败路径——缺少必需章节

**测试夹具 (Fixture)：**
- `docs/architecture/architecture.md` 存在，但至少缺少 2 个必需章节
  （例如，缺少数据模型章节、缺少错误处理章节）
- `production/session-state/review-mode.txt` 包含 `full`

**输入：** `/architecture-review docs/architecture/architecture.md`

**预期行为：**
1. 技能读取文档并识别缺失的章节
2. 章节完整性显示不足 8/8 个章节
3. 缺失章节按名称列出，并附有具体的修正指导
4. 判决：MAJOR REVISION NEEDED（≥2 个缺失章节）

**断言：**
- [ ] 对于 ≥2 个缺失章节，判决为 MAJOR REVISION NEEDED（而非 APPROVED 或 NEEDS REVISION）
- [ ] 每个缺失章节在输出中均被明确命名
- [ ] 修正指导具有针对性（指出添加什么，而非仅"添加缺失章节"）
- [ ] 技能不允许缺少必需章节的文档通过

---

### 用例 3：部分路径——架构与现有 ADR 存在矛盾

**测试夹具 (Fixture)：**
- `docs/architecture/architecture.md` 存在，全部 8 个章节均完备
- `docs/architecture/` 中有一个已接受 (Accepted) 的 ADR 确立了架构文档与之矛盾的约束条件
  （例如，ADR-001 强制要求 ECS 模式；architecture.md 对同一系统描述了不同的模式）

**输入：** `/architecture-review docs/architecture/architecture.md`

**预期行为：**
1. 技能读取架构文档及所有现有 ADR
2. 检测到架构文档与指定 ADR 之间存在冲突
3. 冲突条目包含：ADR 编号/标题、矛盾章节及影响说明
4. 判决：NEEDS REVISION（存在冲突，但整体结构尚可）

**断言：**
- [ ] 对于单一矛盾，判决为 NEEDS REVISION（而非 MAJOR REVISION NEEDED）
- [ ] 冲突条目中标明了具体的 ADR 编号和标题
- [ ] 两篇文档中矛盾的章节均被识别
- [ ] 技能不会自动解决矛盾

---

### 用例 4：边缘情况——文件未找到

**测试夹具 (Fixture)：**
- 提供的路径在项目中不存在

**输入：** `/architecture-review docs/architecture/nonexistent.md`

**预期行为：**
1. 技能尝试读取文件
2. 文件未找到
3. 技能输出明确的错误信息，指明缺失的文件
4. 技能建议检查 `docs/architecture/` 或运行 `/create-architecture`
5. 技能不产出判决

**断言：**
- [ ] 技能在文件未找到时输出明确的错误信息
- [ ] 不产出任何判决（APPROVED / NEEDS REVISION / MAJOR REVISION NEEDED）
- [ ] 技能建议纠正措施
- [ ] 技能不会崩溃或产出部分报告

---

### 用例 5：主管门控——完整模式启动两个门控；单人模式跳过两个门控

**测试夹具（完整模式）：**
- `docs/architecture/architecture.md` 存在，全部 8 个章节均完备
- `production/session-state/review-mode.txt` 包含 `full`

**完整模式预期行为：**
1. TD-ARCHITECTURE 门控启动
2. LP-FEASIBILITY 门控与 TD-ARCHITECTURE 并行启动
3. 两个门控在判决发布前均完成

**断言（完整模式）：**
- [ ] TD-ARCHITECTURE 和 LP-FEASIBILITY 均在输出中显示为已完成的门控
- [ ] 两个门控并行启动（非先后顺序）
- [ ] 判决反映门控反馈

**测试夹具（单人模式）：**
- 同一架构文档
- `production/session-state/review-mode.txt` 包含 `solo`

**单人模式预期行为：**
1. 技能读取架构文档
2. 不启动门控
3. 输出注明："TD-ARCHITECTURE 已跳过——单人模式"和"LP-FEASIBILITY 已跳过——单人模式"
4. 判决仅基于结构检查

**断言（单人模式）：**
- [ ] TD-ARCHITECTURE 和 LP-FEASIBILITY 均不作为活动门控出现
- [ ] 输出中注明两个门控均被跳过
- [ ] 判决仍然基于结构检查单独产出

---

## 协议合规性 (Protocol Compliance)

- [ ] 不写入任何文件（只读技能）
- [ ] 在发布判决前先展示章节完整性检查
- [ ] 完整模式下 TD-ARCHITECTURE 和 LP-FEASIBILITY 并行启动
- [ ] 在精简/单人模式下跳过门控，并按名称和模式注明
- [ ] 判决严格为以下三者之一：APPROVED、NEEDS REVISION、MAJOR REVISION NEEDED
- [ ] 末尾提供与判决相适应的下一步交接指引

---

## 覆盖范围说明 (Coverage Notes)

- 8 个必需要求的架构章节是项目特定的；测试使用技能主体中定义的章节列表——此处不再重复列举。
- 引擎版本兼容性检查（交叉引用 `docs/engine-reference/`）是用例 1 快乐路径的一部分，但未作为独立测试夹具进行测试。
- RTM（需求追溯矩阵，Requirement Traceability Matrix）模式是 `/architecture-review` 技能自身 `rtm` 参数模式的独立关注点，此处不进行测试。
