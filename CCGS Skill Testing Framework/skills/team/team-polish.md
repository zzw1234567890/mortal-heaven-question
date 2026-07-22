# 技能测试规格：/team-polish


## 技能摘要 (Skill Summary)

编排润色团队（polish team）通过六阶段管线：性能评估（performance-analyst）→ 优化（performance-analyst，在发现引擎级根因时可选的 engine-programmer）→ 视觉润色（technical-artist，与阶段 2 并行）→ 音频润色（sound-designer，与阶段 2 并行）→ 加固（qa-tester）→ 签收（编排器收集所有结果并发出 READY FOR RELEASE 或 NEEDS MORE WORK）。每个阶段转换时使用 `AskUserQuestion`。engine-programmer 仅在阶段 1 识别出引擎级根因时有条件地生成。判定为 READY FOR RELEASE 或 NEEDS MORE WORK。

---

## 静态断言（结构类）

- [ ] 具备必填的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 拥有 ≥2 个阶段标题
- [ ] 包含判定关键词：READY FOR RELEASE、NEEDS MORE WORK
- [ ] 包含"文件写入协议"（File Write Protocol）章节
- [ ] 文件写入由子代理委托完成 — 编排器不直接写入文件
- [ ] 子代理在写入前执行"May I write to [path]?"协议
- [ ] 末尾有下一步移交指引（引用了 `/release-checklist`、`/sprint-plan update`、`/gate-check`）
- [ ] 存在错误恢复协议（Error Recovery Protocol）章节
- [ ] `AskUserQuestion` 在阶段转换时用于继续前获取批准
- [ ] 阶段 3（视觉润色）和阶段 4（音频润色）明确与阶段 2 并行运行
- [ ] engine-programmer 仅在阶段 1 识别出引擎级根因时在阶段 2 有条件地生成
- [ ] 阶段 6 签收在发出判定前将指标与预算进行比较

---

## 测试用例

### 用例 1：正常路径 — 完整管线完成，判定 READY FOR RELEASE

**测试夹具 (Fixture)：**
- 特性存在且功能完整（例如 `combat` 系统）
- 性能预算在 technical-preferences.md 中定义（例如目标 60fps，16ms 帧预算）
- 润色开始前不存在帧预算违规
- 无缺失音频事件；VFX 资源完整
- 润色更改未引入回归

**输入：** `/team-polish combat`

**预期行为：**
1. 阶段 1：生成 performance-analyst；对战斗系统进行分析，测量帧预算，检查内存使用；输出：性能报告，显示所有指标在预算内，无违规
2. `AskUserQuestion` 展示性能报告；用户在阶段 2、3 和 4 开始前批准
3. 阶段 2：performance-analyst 应用小幅优化（例如绘制调用批次合并）；无需 engine-programmer（未发现引擎级根因）
4. 阶段 3 和阶段 4 与阶段 2 同时启动：
   - 阶段 3：technical-artist 审查 VFX 质量，优化粒子系统，添加屏幕震动和视觉效果增强（visual juice）
   - 阶段 4：sound-designer 审查音频事件完整性，检查混音电平，添加环境音频层
5. 三个并行阶段全部完成；`AskUserQuestion` 展示结果；用户在阶段 5 开始前批准
6. 阶段 5：qa-tester 运行边界用例测试、浸泡测试、压力测试和回归测试；全部通过
7. `AskUserQuestion` 展示测试结果；用户在阶段 6 前批准
8. 阶段 6：编排器收集所有结果；将润色前后的性能指标与预算进行比较；所有指标通过
9. 子代理在写入前询问"May I write the polish report to `production/qa/evidence/polish-combat-[date].md`?"
10. 判定：READY FOR RELEASE

**断言：**
- [ ] performance-analyst 在阶段 1 优先于其他所有代理生成
- [ ] `AskUserQuestion` 出现在阶段 1 输出之后、阶段 2/3/4 启动之前
- [ ] 阶段 3 和阶段 4 的 Task 调用与阶段 2 同时发出（而非在阶段 2 完成后）
- [ ] 阶段 1 未发现引擎级根因时，不生成 engine-programmer
- [ ] qa-tester（阶段 5）在并行阶段完成且用户批准后才启动
- [ ] 阶段 6 判定基于指标与已定义预算的比较
- [ ] 摘要报告包含：润色前后性能指标、视觉润色变更、音频润色变更、测试结果
- [ ] 编排器不直接写入任何文件
- [ ] 判定为 READY FOR RELEASE

---

### 用例 2：性能阻塞 — 帧预算违规无法完全解决

**测试夹具 (Fixture)：**
- 正在润色的特性：`particle-storm` VFX 系统
- 阶段 1 识别出帧预算违规：particle-storm 在目标硬件上消耗 12ms（该系统的预算为 6ms）
- 阶段 2 performance-analyst 应用优化后成本降至 9ms — 仍超出 6ms 预算
- 阶段 2 无法在不大幅更改设计的情况下完全解决违规

**输入：** `/team-polish particle-storm`

**预期行为：**
1. 阶段 1：performance-analyst 识别出 12ms 帧成本 vs 6ms 预算；报告"FRAME BUDGET VIOLATION: particle-storm costs 12ms, budget is 6ms"
2. `AskUserQuestion` 展示该违规；用户选择继续进行优化尝试
3. 阶段 2：performance-analyst 应用优化；达到 9ms — 已降低但仍超预算；报告"Optimization reduced cost to 9ms (was 12ms) — 3ms over budget. No further gains achievable without design changes."
4. 阶段 3 和阶段 4 与阶段 2 并行运行（视觉和音频润色）
5. 阶段 5：qa-tester 运行回归和边界用例测试；全部通过
6. 阶段 6：编排器收集结果；帧预算违规（9ms vs 6ms 预算）仍未解决
7. 判定：NEEDS MORE WORK
8. 报告列出具体的未解决问题："particle-storm frame cost (9ms) exceeds budget (6ms) by 3ms — requires design scope reduction or budget renegotiation"
9. 下一步：将剩余问题安排在 `/sprint-plan update` 中；修复后重新运行 `/team-polish`

**断言：**
- [ ] 帧预算违规在阶段 1 中以具体数值（实际值 vs 预算值）标记
- [ ] 阶段 2 明确报告优化后的指标（达到 9ms，仍超 3ms）
- [ ] 当存在预算违规时判定为 NEEDS MORE WORK（而非 READY FOR RELEASE）
- [ ] 具体的未解决问题按名称列出，附剩余差距的量化说明
- [ ] 下一步引用了 `/sprint-plan update` 用于安排剩余修复
- [ ] 阶段 3 和阶段 4 仍然运行（润色工作不会因阶段 2 的部分解决而放弃）
- [ ] 阶段 5 qa-tester 仍然运行（回归测试独立于性能结果）

---

### 用例 3：无参数 — 显示使用指引

**测试夹具 (Fixture)：**
- 任意项目状态

**输入：** `/team-polish`（无参数）

**预期行为：**
1. 技能检测到未提供参数
2. 输出使用指引：例如 "Usage: `/team-polish [feature or area]` — specify the feature or area to polish (e.g., `combat`, `main menu`, `inventory system`, `level-1`)"
3. 技能退出，不生成任何代理

**断言：**
- [ ] 未提供参数时，技能不会生成任何代理
- [ ] 使用消息包含正确的调用格式及参数示例
- [ ] 技能不会尝试从项目文件中猜测特性
- [ ] 不使用 `AskUserQuestion` — 输出为直接指引

---

### 用例 4：引擎级瓶颈 — engine-programmer 在阶段 2 有条件地生成

**测试夹具 (Fixture)：**
- 正在润色的特性：`open-world` 环境流式加载
- 阶段 1 识别出渲染管线中的性能瓶颈根因："draw call overhead is caused by the engine's scene tree traversal in the spatial indexer — this is an engine-level issue, not a game code issue"
- 性能预算已定义；渲染开销超出目标帧预算

**输入：** `/team-polish open-world`

**预期行为：**
1. 阶段 1：performance-analyst 对环境进行分析；识别出帧预算违规；根因分析指向引擎级渲染管线（空间索引器遍历开销）
2. 阶段 1 输出将根因明确归类为引擎级
3. `AskUserQuestion` 展示包含引擎级根因的性能报告；用户在阶段 2 前批准
4. 阶段 2：performance-analyst 用于游戏代码级优化，同时 engine-programmer 并行生成以处理引擎级渲染修复
5. 阶段 3 和阶段 4 也与阶段 2 并行运行（视觉和音频润色）
6. engine-programmer 处理空间索引器遍历问题；提供分析器验证显示修复减少了开销
7. 阶段 5：qa-tester 运行回归测试，包括对引擎级修复的测试
8. 阶段 6：编排器收集所有结果；若指标现在在预算内，判定为 READY FOR RELEASE；否则为 NEEDS MORE WORK

**断言：**
- [ ] 除非阶段 1 明确识别出引擎级根因，否则 engine-programmer 不会在阶段 2 生成
- [ ] 阶段 1 识别出引擎级根因时，engine-programmer 在阶段 2 生成
- [ ] 阶段 2 中 engine-programmer 和 performance-analyst 的 Task 调用同时发出（非顺序执行）
- [ ] 阶段 3 和阶段 4 也与阶段 2 并行运行（不会推迟到阶段 2 完成后）
- [ ] engine-programmer 的输出包含对修复的分析器验证
- [ ] 阶段 5 的 qa-tester 运行覆盖引擎级变更的回归测试
- [ ] 判定正确反映包括引擎修复在内的所有指标是否满足预算

---

### 用例 5：发现回归 — 润色变更破坏了已有功能

**测试夹具 (Fixture)：**
- 正在润色的特性：`inventory-ui`
- 阶段 1–4 成功完成；性能和润色变更已应用
- 阶段 5：qa-tester 运行回归测试，发现阶段 3 应用的一项着色器优化破坏了悬停时物品高亮发光效果 — 该功能在润色通过前是可用的

**输入：** `/team-polish inventory-ui`（阶段 5 场景）

**预期行为：**
1. 阶段 1–4 完成；润色变更包括来自 technical-artist 的着色器优化
2. 阶段 5：qa-tester 运行回归测试并检测到"Item highlight glow on hover no longer renders — regression introduced by shader optimization in Phase 3"
3. qa-tester 返回附带已记录回归的测试结果
4. 编排器立即呈现回归："qa-tester: REGRESSION FOUND — `item-highlight-hover` glow broken by Phase 3 shader optimization"
5. 子代理在写入前询问"May I write the bug report to `production/qa/evidence/bug-polish-inventory-ui-[date].md`?"
6. 获批后写入错误报告；报告包含：被破坏的行为、导致该问题的润色变更、复现步骤及严重性
7. `AskUserQuestion` 提供回归处理选项：
   - 回退着色器优化并寻找替代方案
   - 修复着色器优化以保留发光效果
   - 接受该回归并在下一个冲刺中安排修复
8. 判定：NEEDS MORE WORK（无论用户选择何种解决路径，只要回归存在且未解决；除非在当前会话中已应用修复）

**断言：**
- [ ] 回归在阶段 6 签收前被呈现
- [ ] 报告中同时指出具体的被破坏行为和导致问题的变更
- [ ] 子代理在提交前询问"May I write the bug report to [path]?"
- [ ] 错误报告包含：被破坏的行为、导致变更、复现步骤、严重性
- [ ] `AskUserQuestion` 提供包括回退、就地修复和后续安排的选项
- [ ] 当回归存在且未解决时判定为 NEEDS MORE WORK
- [ ] 仅当回归在当前润色会话中修复且 qa-tester 重新验证后，判定才可能变为 READY FOR RELEASE

---

## 协议合规性

- [ ] 阶段 1（评估）必须在任何其他阶段开始前完成
- [ ] 在每个阶段输出之后、下一阶段启动之前使用 `AskUserQuestion`
- [ ] 阶段 3 和阶段 4 始终与阶段 2 同时启动（不会推迟）
- [ ] engine-programmer 仅在阶段 1 明确识别出引擎级根因时生成
- [ ] 编排器不直接写入任何文件 — 所有写入由子代理委托完成
- [ ] 每个子代理在写入前执行"May I write to [path]?"协议
- [ ] 任何代理的 BLOCKED 状态立即呈现 — 不会静默跳过
- [ ] 当部分代理完成而其他代理被阻塞时，始终产出部分报告
- [ ] 判定严格为 READY FOR RELEASE 或 NEEDS MORE WORK — 不使用其他判定值
- [ ] NEEDS MORE WORK 判定始终列出具体的剩余问题及严重性
- [ ] 下一步移交指引引用了 `/release-checklist`（成功时）和 `/sprint-plan update` + `/gate-check`（失败时）

---

## 覆盖说明

- tools-programmer 可选代理（用于内容管线工具验证）未单独测试 — 它遵循与 engine-programmer 相同的有条件生成模式，且仅在被润色区域涉及内容创作工具时才被调用。
- "缩小范围重试"和"跳过此代理"的错误恢复协议解决路径未单独测试 — 它们遵循与用例 2 和 5 相同的 `AskUserQuestion` + 部分报告模式。
- 阶段 6 签收逻辑（收集和比较所有指标）由用例 1 和 2 隐式验证。READY FOR RELEASE 与 NEEDS MORE WORK 的区分在跨用例的两个方向上均得到了演练。
- 浸泡测试和压力测试（阶段 5）由用例 1 的 qa-tester 输出隐式验证。用例 5 聚焦于阶段 5 的回归检测方面。
- 阶段 5 的"最低规格硬件"测试路径未单独测试 — 当硬件可用时它遵循相同的 qa-tester 委托模式。
