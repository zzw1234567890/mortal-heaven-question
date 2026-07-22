
# 技能测试规格：/milestone-review

## 技能概述 (Skill Summary)

`/milestone-review` 生成已完成里程碑 (milestone) 的全面审查：交付内容、速度指标、延期项、暴露的风险以及回顾性种子。在完整模式下，PR-MILESTONE 主管门控 (director gate) 在审查编译后运行（制作人 (producer) 审查范围交付情况）。在精简和单人模式下，该门控被跳过。该技能在持久化之前会询问"我可以写入 `production/milestones/review-milestone-N.md` 吗？"。判决 (verdict)：MILESTONE COMPLETE（里程碑完成）或 MILESTONE INCOMPLETE（里程碑未完成）。

---

## 静态断言（结构）

由 `/skill-test static` 自动验证——无需测试夹具 (fixture)。

- [ ] 包含所需 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判决关键词：MILESTONE COMPLETE、MILESTONE INCOMPLETE
- [ ] 包含"我可以写入吗"这一类用语（技能会写入审查文档）
- [ ] 具有下一步交接指引（审查写入后该做什么）

---

## 主管门控检查 (Director Gate Checks)

| 门控 ID      | 触发条件               | 模式守卫              |
|---------------|------------------------|-----------------------|
| PR-MILESTONE  | 审查文档编译完成之后      | 仅完整模式（非精简/单人） |

---

## 测试用例 (Test Cases)

### 用例 1：快乐路径——几乎完成的里程碑，有一个延期故事

**测试夹具 (Fixture)：**
- `production/milestones/milestone-03.md` 存在，包含 8 个故事
- 7 个故事的状态为 `Status: Complete`
- 1 个故事的状态为 `Status: Deferred`（延期至 milestone-04）
- `review-mode.txt` 包含 `full`

**输入：** `/milestone-review milestone-03`

**预期行为：**
1. 技能读取 `milestone-03.md` 及所有引用的冲刺文件
2. 技能编译：7 个已交付，1 个延期；速度；无阻塞项
3. 技能向用户展示审查草稿
4. 调用 PR-MILESTONE 门控；制作人批准
5. 技能询问"我可以写入 `production/milestones/review-milestone-03.md` 吗？"
6. 用户批准；文件写入；判决 MILESTONE COMPLETE

**断言 (Assertions)：**
- [ ] 延期故事在审查中被注明，并附有其目标里程碑
- [ ] 尽管有一个延期故事，判决仍为 MILESTONE COMPLETE
- [ ] 在完整模式下，PR-MILESTONE 门控在草稿编译后被调用
- [ ] 技能在写入审查文件前询问"我可以写入吗"
- [ ] 审查文档路径匹配 `production/milestones/review-milestone-03.md`

---

### 用例 2：受阻的里程碑——多个受阻故事

**测试夹具 (Fixture)：**
- `production/milestones/milestone-03.md` 存在，包含 5 个故事
- 2 个故事的状态为 `Status: Complete`
- 3 个故事的状态为 `Status: Blocked`（每个故事中列出了命名的阻塞项）
- `review-mode.txt` 包含 `full`

**输入：** `/milestone-review milestone-03`

**预期行为：**
1. 技能读取里程碑和冲刺文件
2. 技能发现 3 个受阻故事；编译阻塞项详情
3. 判决为 MILESTONE INCOMPLETE
4. PR-MILESTONE 门控运行；制作人记录未解决的阻塞项
5. 批准后，审查写入并附带阻塞项列表

**断言：**
- [ ] 当有任何故事处于 Blocked 状态时，判决为 MILESTONE INCOMPLETE
- [ ] 每个受阻故事的名称和阻塞原因均在审查中列出
- [ ] 即使在 INCOMPLETE 判决下，完整模式下仍会调用 PR-MILESTONE 门控
- [ ] 文件写入前仍出现"我可以写入吗"提示

---

### 用例 3：完整模式——PR-MILESTONE 返回 CONCERNS（关注点）

**测试夹具 (Fixture)：**
- Milestone-03 有 6 个已完成故事，但其中 2 个不在原始范围中（冲刺中期添加）
- `review-mode.txt` 包含 `full`

**输入：** `/milestone-review milestone-03`

**预期行为：**
1. 技能编译审查；注明交付了 2 个范围外的故事
2. 调用 PR-MILESTONE 门控；制作人返回 CONCERNS（关于范围蔓延）
3. 技能向用户展示 CONCERNS，并在审查中添加"范围蔓延"说明
4. 用户批准修订后的审查；文件写入，结果为 MILESTONE COMPLETE 但附有附带说明

**断言：**
- [ ] PR-MILESTONE 门控的 CONCERNS 在写入前向用户展示
- [ ] 写入的审查文档中明确注明了范围蔓延
- [ ] 判决为 MILESTONE COMPLETE（故事已交付）并附有 CONCERNS 注释
- [ ] 技能不会压制门控反馈

---

### 用例 4：边缘情况——指定里程碑的文件未找到

**测试夹具 (Fixture)：**
- 用户调用 `/milestone-review milestone-07`
- `production/milestones/milestone-07.md` 不存在

**输入：** `/milestone-review milestone-07`

**预期行为：**
1. 技能尝试读取 `production/milestones/milestone-07.md`
2. 文件未找到；技能输出错误信息
3. 技能建议检查 `production/milestones/` 中的可用里程碑
4. 不调用门控；不写入文件

**断言：**
- [ ] 里程碑文件不存在时，技能不会崩溃
- [ ] 输出在错误信息中指明了预期的文件路径
- [ ] 输出建议检查 `production/milestones/` 获取有效的里程碑名称
- [ ] 判决为 BLOCKED（无法审查一个不存在的里程碑）

---

### 用例 5：精简/单人模式——PR-MILESTONE 门控被跳过

**测试夹具 (Fixture)：**
- `production/milestones/milestone-03.md` 存在，包含 5 个已完成故事
- `review-mode.txt` 包含 `solo`

**输入：** `/milestone-review milestone-03`

**预期行为：**
1. 技能读取审查模式——确定为 `solo`
2. 技能编译审查草稿
3. PR-MILESTONE 门控被跳过；输出注明"[PR-MILESTONE] 已跳过——单人模式"
4. 技能请求用户直接批准该审查
5. 用户批准；审查文件写入；判决 MILESTONE COMPLETE

**断言：**
- [ ] 在单人（或精简）模式下，PR-MILESTONE 门控未被调用
- [ ] 技能输出中明确注明了跳过
- [ ] 写入前仍需用户直接批准
- [ ] 成功写入后判决为 MILESTONE COMPLETE

---

## 协议合规性 (Protocol Compliance)

- [ ] 在调用 PR-MILESTONE 或请求写入之前，先展示编译后的审查草稿
- [ ] 在写入审查文档前始终询问"我可以写入吗"
- [ ] PR-MILESTONE 门控仅在完整模式下运行
- [ ] 精简和单人模式输出中出现跳过消息
- [ ] 判决为 MILESTONE COMPLETE 或 MILESTONE INCOMPLETE，明确声明

---

## 覆盖范围说明 (Coverage Notes)

- 里程碑包含零个故事的情况未进行测试；它遵循 MILESTONE INCOMPLETE 模式，并附带建议该里程碑可能尚未规划的说明。
- 速度计算的具体细节（故事点数 vs. 故事数量）在此处未经验证；它们是审查编译阶段的实现细节。
