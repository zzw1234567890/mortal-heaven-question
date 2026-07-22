# 技能测试规格：/team-live-ops


## 技能摘要 (Skill Summary)

编排运营团队（live-ops team）通过 7 阶段规划管线（pipeline）来产出赛季或活动计划。协调 live-ops-designer、economy-designer、analytics-engineer、community-manager、narrative-director 和 writer。阶段 3 和阶段 4（经济设计与分析）可同时运行。最终产出一份整合的赛季计划，需经用户批准后方可移交至制作阶段。

---

## 静态断言（结构类）

- [ ] 具备必填的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 拥有 ≥2 个阶段标题
- [ ] 包含判定关键词：COMPLETE、BLOCKED
- [ ] 在"文件写入协议"（File Write Protocol）章节中包含"May I write"措辞（由子代理委托执行）
- [ ] 拥有文件写入协议章节，声明编排器不直接写入文件
- [ ] 末尾有下一步移交指引，引用了 `/design-review`、`/sprint-plan` 和 `/team-release`
- [ ] 在阶段转换时使用 `AskUserQuestion` 以在继续前获取用户批准
- [ ] 明确声明阶段 3 和阶段 4 可同时运行（并行生成）
- [ ] 存在错误恢复章节（或通过 BLOCKED 处理机制隐含）
- [ ] 输出文档章节指定了 `design/live-ops/seasons/` 下的路径

---

## 测试用例

### 用例 1：正常路径 — 全部 7 个阶段完成，产出赛季计划

**测试夹具 (Fixture)：**
- `design/live-ops/economy-rules.md` 存在，包含当前经济配置
- `design/live-ops/ethics-policy.md` 存在，包含项目伦理政策
- 游戏概念文档在其标准路径下存在
- 不存在与新规划赛季名称重复的已有赛季文档

**输入：** `/team-live-ops "Season 2: The Frozen Wastes"`

**预期行为：**
1. 阶段 1：通过 Task 生成 `live-ops-designer`；接收包含范围、内容列表和留存机制的赛季简报；展示给用户
2. AskUserQuestion：用户在阶段 2 开始前批准阶段 1 输出
3. 阶段 2：通过 Task 生成 `narrative-director`；读取阶段 1 的赛季简报；产出叙事框架文档（主题、故事钩子、世界观关联）；展示给用户
4. 阶段 3 和阶段 4（并行）：同时通过两个 Task 调用生成 `economy-designer` 和 `analytics-engineer`，不等待任一结果；economy-designer 读取 `design/live-ops/economy-rules.md`
5. 阶段 5：并行生成 `narrative-director` 和 `writer` 以产出游戏内叙事文本和面向玩家的文案；两者均读取阶段 2 的叙事框架文档
6. 阶段 6：通过 Task 生成 `community-manager`；读取赛季简报、经济设计和叙事框架；产出含草稿文案的沟通日历
7. 阶段 7：收集所有阶段输出；展示整合的赛季计划摘要，包含经济健康检查、分析就绪度、伦理审查和待解决问题
8. AskUserQuestion：用户批准完整的赛季计划
9. 子代理在写入前询问"May I write to `design/live-ops/seasons/S2_The_Frozen_Wastes.md`?"、`...analytics.md` 和 `...comms.md`？
10. 判定：COMPLETE — 赛季计划已产出并移交至制作

**断言：**
- [ ] 全部 7 个阶段按序执行；阶段 3 和阶段 4 以并行 Task 调用发起
- [ ] 阶段 7 的整合摘要包含全部六个部分（赛季简报、叙事框架、经济设计、分析计划、内容清单、沟通日历）
- [ ] 阶段 7 的伦理审查部分明确引用 `design/live-ops/ethics-policy.md`
- [ ] 三份输出文档写入 `design/live-ops/seasons/`，命名规范正确
- [ ] 文件写入由子代理委托完成 — 编排器不直接写入
- [ ] 判定：COMPLETE 出现在最终输出中
- [ ] 下一步引用了 `/design-review`、`/sprint-plan` 和 `/team-release`

---

### 用例 2：发现伦理违规 — 奖励元素违反伦理政策

**测试夹具 (Fixture)：**
- 所有标准运营团队夹具均存在（economy-rules.md、ethics-policy.md）
- `design/live-ops/ethics-policy.md` 明确禁止面向 18 岁以下玩家的开箱机制
- economy-designer（阶段 3）提议了一个"神秘宝箱"（Mystery Chest）机制，包含随机化高级奖励且无保底计时器

**输入：** `/team-live-ops "Season 3: Shadow Tournament"`

**预期行为：**
1. 阶段 1–4 正常进行；economy-designer 提议了神秘宝箱机制
2. 阶段 7：编排器根据伦理政策审查阶段 3 输出；确认神秘宝箱违反了伦理政策中"禁止不透明随机高级奖励"的规则
3. 阶段 7 摘要中的伦理审查部分明确标注该违规："ETHICS FLAG: Mystery Chest mechanic in Phase 3 economy design violates [policy rule]. Approval is blocked until this is resolved."
4. 在提供赛季计划批准选项之前，通过 AskUserQuestion 展示解决方案选项
5. 在伦理违规解决或被用户明确豁免之前，技能不会发出 COMPLETE 判定或写入输出文档

**断言：**
- [ ] 阶段 7 伦理审查部分明确指出违规元素及其违反的政策条款
- [ ] 当存在伦理违规时，技能不会自动批准赛季计划
- [ ] AskUserQuestion 用于呈现违规并提供解决方案选项（修改经济设计、附文档说明理由后覆盖、取消）
- [ ] 违规未解决时不会写入输出文档
- [ ] 若用户选择修改：技能重新生成 economy-designer 产出修正设计后再返回阶段 7 审查
- [ ] 判定：COMPLETE 仅在伦理标记清除后才可发出

---

### 用例 3：无参数 — 显示使用指引

**测试夹具 (Fixture)：**
- 任意项目状态

**输入：** `/team-live-ops`（无参数）

**预期行为：**
1. 阶段 1：检测到未提供参数
2. 输出："Usage: `/team-live-ops [season name or event description]` — Provide the name or description of the season or live event to plan."
3. 技能立即退出，不生成任何子代理

**断言：**
- [ ] 技能不会猜测赛季名称或虚构范围
- [ ] 错误消息包含正确的使用格式及 argument-hint
- [ ] 在参数检查失败之前不会发起任何 Task 调用
- [ ] 不会读取或写入任何文件

---

### 用例 4：并行阶段验证 — 阶段 3 和阶段 4 同时运行

**测试夹具 (Fixture)：**
- 所有标准运营团队夹具均存在
- 阶段 1（赛季简报）和阶段 2（叙事框架）已获批准
- 阶段 3（economy-designer）和阶段 4（analytics-engineer）的输入互不依赖

**输入：** `/team-live-ops "Season 1: The First Thaw"`（在阶段 3/4 转换点观察）

**预期行为：**
1. 用户批准阶段 2 后，编排器在等待任一结果之前同时发起两个 Task 调用（economy-designer 和 analytics-engineer）
2. 两个代理均接收赛季简报作为上下文；analytics-engineer 不会等待 economy-designer 的输出才开始工作
3. economy-designer 输出和 analytics-engineer 输出在阶段 5 开始前一并收集
4. 若其中一个并行代理被阻塞，另一个继续运行；产出部分报告

**断言：**
- [ ] 阶段 3 和阶段 4 的两个 Task 调用在等待任一结果之前均已发出 — 非顺序执行
- [ ] analytics-engineer 的提示中不包含 economy-designer 输出作为必需输入（两者输入独立）
- [ ] 若 economy-designer 被阻塞但 analytics-engineer 成功，分析输出被保留，且阻塞通过 AskUserQuestion 呈现
- [ ] 阶段 5 在阶段 3 和阶段 4 结果均已收集后才开始
- [ ] 技能文档明确声明"阶段 3 和阶段 4 可同时运行"

---

### 用例 5：伦理政策缺失 — `design/live-ops/ethics-policy.md` 不存在

**测试夹具 (Fixture)：**
- `design/live-ops/economy-rules.md` 存在
- `design/live-ops/ethics-policy.md` 不存在
- 其他所有夹具均存在

**输入：** `/team-live-ops "Season 4: Desert Heat"`

**预期行为：**
1. 阶段 1–4 进行中；economy-designer 和 analytics-engineer 被赋予伦理政策路径但该文件不存在
2. 阶段 7：编排器尝试执行伦理审查；检测到 `design/live-ops/ethics-policy.md` 缺失
3. 阶段 7 摘要包含缺失标记："ETHICS REVIEW SKIPPED: `design/live-ops/ethics-policy.md` not found. Economy design was not reviewed against an ethics policy. Recommend creating one before production begins."
4. 技能仍完成赛季计划并达到 COMPLETE 判定，但该缺失在输出和赛季设计文档中被显著标注
5. 下一步包含创建伦理政策文档的建议

**断言：**
- [ ] 当伦理政策文件缺失时，技能不会报错退出
- [ ] 技能在文件缺失时不会凭空编造伦理政策规则
- [ ] 阶段 7 摘要明确注明伦理审查已被跳过及原因
- [ ] 即使缺少该文件，判定仍可达到 COMPLETE
- [ ] 缺失标记出现在赛季设计输出文档中（不仅在对话中）
- [ ] 下一步建议创建 `design/live-ops/ethics-policy.md`

---

## 协议合规性

- [ ] 在每个阶段转换时使用 `AskUserQuestion` — 用户在下一阶段开始前批准
- [ ] 阶段 3 和阶段 4 始终并行生成，而非顺序执行
- [ ] 文件写入协议：编排器从不直接调用 Write/Edit — 所有写入由子代理委托完成
- [ ] 每份输出文档由相关子代理发出各自的"May I write to [path]?"询问
- [ ] 阶段 7 的伦理审查始终明确引用伦理政策文件路径
- [ ] 错误恢复：任何被 BLOCKED 的代理立即通过 AskUserQuestion 选项呈现（跳过 / 重试 / 停止）
- [ ] 当任何阶段被阻塞时，始终产出部分报告 — 已完成的工作不会被丢弃
- [ ] 判定：COMPLETE 仅在用户批准整合赛季计划后发出；若存在未解决的伦理违规则为 BLOCKED
- [ ] 下一步始终包含 `/design-review`、`/sprint-plan` 和 `/team-release`

---

## 覆盖说明

- 阶段 5 的并行生成（narrative-director + writer）遵循与阶段 3/4 相同的模式，但未在此单独测试 — 使用的是用例 4 中已验证的相同并行 Task 协议。
- "economy-rules.md 缺失"的边界情况未单独测试 — 它会以 economy-designer 的 BLOCKED 结果呈现，并遵循用例 4 中隐式测试的标准错误恢复路径。
- 完整的内容写入管线（阶段 5 输出验证）由用例 1 正常路径的整合摘要检查隐式验证。
- 社区经理沟通日历格式（预发布、发布日、赛季中期、最后一周）由用例 1 隐式验证；无需单独的边界用例。
