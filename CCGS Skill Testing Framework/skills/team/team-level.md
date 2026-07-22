# Skill 测试规格：/team-level


## Skill 概述

为单个关卡或区域编排完整的关卡设计团队。通过五个顺序步骤（其中第 4 步为并行阶段）协调
narrative-director、world-builder、level-designer、systems-designer、art-director、
accessibility-specialist 和 qa-tester。将所有团队产出汇编为一份关卡设计
文档，保存到 `design/levels/[level-name].md`。在每个步骤转换处使用 `AskUserQuestion`。
所有文件写入均委托给子代理。产出摘要报告，结论为 COMPLETE / BLOCKED，并交接给
`/design-review`、`/dev-story`、`/qa-plan`。

---

## 静态断言（结构性）

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段/步骤标题（Step 1 到 Step 5 全部存在）
- [ ] 包含结论关键词：COMPLETE、BLOCKED
- [ ] 包含 "May I write" 或 "File Write Protocol" —— 写入委托给子代理，编排者不直接写文件
- [ ] 末尾有下一步交接（引用 `/design-review`、`/dev-story`、`/qa-plan`）
- [ ] 存在 Error Recovery Protocol 章节，且包含全部四个恢复步骤
- [ ] 在步骤转换处使用 `AskUserQuestion`，在继续前征得用户批准
- [ ] Step 4 明确标记为并行（art-director 和 accessibility-specialist 同时运行）
- [ ] 上下文收集读取：`design/gdd/game-concept.md`、`design/gdd/game-pillars.md`、`design/levels/`、`design/narrative/` 以及相关世界观文档
- [ ] 团队组成列出全部七个角色（narrative-director、world-builder、level-designer、systems-designer、art-director、accessibility-specialist、qa-tester）
- [ ] accessibility-specialist 的输出包含严重级别评级（BLOCKING / RECOMMENDED / NICE TO HAVE）
- [ ] 最终关卡设计文档保存到 `design/levels/[level-name].md`

---

## 测试用例

### 用例 1：顺利路径 —— 所有团队成员产出成果，文档汇编并保存

**前置条件（Fixture）：**
- `design/gdd/game-concept.md` 存在且已填充内容
- `design/gdd/game-pillars.md` 存在
- `design/levels/` 目录存在（可能包含其他关卡文档）
- `design/narrative/` 目录存在且包含相关叙事文档

**输入：** `/team-level forest dungeon`

**预期行为：**
1. 上下文收集 —— 编排者读取 game-concept.md、game-pillars.md、`design/levels/` 中现有关卡文档、`design/narrative/` 中的叙事文档，以及森林区域的世界观文档
2. Step 1 —— 启动 narrative-director：定义叙事目的、关键角色、对话触发点、情感弧线；启动 world-builder：提供世界观背景、环境叙事机会、世界规则；`AskUserQuestion` 在进入 Step 2 前确认 Step 1 的产出
3. Step 2 —— 启动 level-designer：设计空间布局（关键路径、可选路径、秘密区域）、节奏曲线、遭遇战、谜题、出入口以及与相邻区域的连接；`AskUserQuestion` 在进入 Step 3 前确认布局
4. Step 3 —— 启动 systems-designer：明确敌人配置、掉落表、难度平衡、区域特有机制、资源分布；`AskUserQuestion` 在进入 Step 4 前确认系统设计
5. Step 4 —— art-director 和 accessibility-specialist 并行启动；art-director：视觉主题、色彩方案、光照、资产清单、VFX 需求；accessibility-specialist：导航清晰度、色盲安全、认知负荷检查 —— 每项关注点评级为 BLOCKING / RECOMMENDED / NICE TO HAVE；`AskUserQuestion` 在进入 Step 5 前展示两份产出
6. Step 5 —— 启动 qa-tester：关键路径测试用例、边界/边缘用例（时序破坏、软锁）、试玩测试清单、验收标准
7. 编排者将所有团队产出汇编为关卡设计文档格式；子代理被询问 "May I write to `design/levels/forest-dungeon.md`?"；文件保存
8. 摘要报告：区域概览、遭遇战数量、预估资产清单、叙事节拍、跨团队依赖，结论：COMPLETE
9. 列出后续步骤：`/design-review design/levels/forest-dungeon.md`、`/dev-story`、`/qa-plan`

**断言：**
- [ ] 在启动任何代理之前，上下文收集阶段读取了全部五类来源
- [ ] narrative-director 和 world-builder 都在 Step 1 启动（可顺序也可并行 —— 两者都必须在 Step 2 前完成）
- [ ] 每个步骤关口都调用了 `AskUserQuestion`（至少：Step 1、2、3、4 之后）
- [ ] Step 4 的代理（art-director、accessibility-specialist）同时启动
- [ ] 所有文件写入均委托给子代理 —— 编排者不直接写入
- [ ] 关卡文档保存到 `design/levels/forest-dungeon.md`（由参数 slug 化得到）
- [ ] 最终摘要报告中结论为 COMPLETE
- [ ] 后续步骤包含 `/design-review`、`/dev-story`、`/qa-plan`
- [ ] 摘要报告包含：区域概览、遭遇战数量、预估资产清单、叙事节拍

---

### 用例 2：代理受阻（world-builder）—— 产出部分报告并注明缺口

**前置条件（Fixture）：**
- `design/gdd/game-concept.md` 存在
- 森林区域的世界观文档不存在
- world-builder 代理返回 BLOCKED："No world-building docs found for the forest region — cannot provide lore context"

**输入：** `/team-level forest dungeon`

**预期行为：**
1. 上下文收集完成；记录了世界观文档缺失
2. Step 1 —— narrative-director 成功完成；world-builder 启动并返回 BLOCKED
3. 触发 Error Recovery Protocol："world-builder: BLOCKED — no world-building docs for forest region"
4. `AskUserQuestion` 提供选项：
   - (a) 跳过 world-builder，并在关卡文档中注明世界观缺口
   - (b) 缩小范围重试（world-builder 仅基于 game-concept.md 可推断的内容工作）
   - (c) 在此停止，先创建世界观文档
5. 如果用户选择 (a)：流水线仅使用 narrative-director 的上下文继续执行 Step 2–5；关卡文档汇编时带有明确标记的缺口小节："World-building context: NOT PROVIDED — see open dependency"
6. 产出最终报告：记录部分产出，world-builder 小节标记为 BLOCKED，总体结论：BLOCKED

**断言：**
- [ ] world-builder 失败时立即浮现 BLOCKED 消息 —— 不会在未经用户输入的情况下进入 Step 2
- [ ] `AskUserQuestion` 至少提供三个选项（跳过 / 重试 / 停止）
- [ ] 产出部分报告 —— narrative-director 已完成的工作不被丢弃
- [ ] 关卡文档（若已汇编）对缺失的世界观上下文包含明确的缺口标注
- [ ] world-builder 未解决时，总体结论为 BLOCKED（而非 COMPLETE）
- [ ] Skill 不会悄悄编造世界观内容来填补缺口

---

### 用例 3：无参数 —— 显示用法指引

**前置条件（Fixture）：**
- 任意项目状态

**输入：** `/team-level`（无参数）

**预期行为：**
1. Skill 检测到未提供参数
2. 输出用法消息，说明必需参数（要设计的关卡名称或区域）
3. 提供调用示例：`/team-level tutorial`、`/team-level forest dungeon`、`/team-level final boss arena`
4. Skill 退出，不读取任何项目文件，也不启动任何子代理

**断言：**
- [ ] 未提供参数时，Skill 不启动任何子代理
- [ ] 用法消息包含 frontmatter 中的 argument-hint 格式
- [ ] 至少展示一个有效调用示例
- [ ] 失败前不读取任何 GDD 或关卡文件
- [ ] 不显示结论（流水线从未启动）

---

### 用例 4：无障碍审查关口 —— 阻塞性问题在签核前浮现

**前置条件（Fixture）：**
- Step 1–3 成功完成
- `design/accessibility-requirements.md` 承诺的级别：Enhanced
- accessibility-specialist（Step 4，并行）标记了一个 BLOCKING 问题：穿越森林地牢的关键路径要求玩家仅凭颜色区分两种环境危害（毒池 vs 浅水）—— 没有形状、图标或音频线索来区分它们

**输入：** `/team-level forest dungeon`

**预期行为：**
1. Step 1–3 完成；Step 4 并行阶段开始
2. accessibility-specialist 返回：BLOCKING 问题 —— "Critical path hazard distinction relies on color only (toxic pools vs. shallow water). Shape, icon, or audio cue required per Enhanced accessibility tier."
3. art-director 返回 Step 4 产出（完整）
4. Skill 通过 `AskUserQuestion` 展示两份 Step 4 结果 —— BLOCKING 问题被突出显示
5. `AskUserQuestion` 提供：
   - (a) 返回 level-designer + art-director，在进入 Step 5 前重新设计危害的视觉/音频语言
   - (b) 将其记录为已知无障碍缺口，在记录该问题后继续 Step 5
6. Skill 不会悄悄越过 BLOCKING 问题继续执行
7. 如果用户选择 (a)：启动 level-designer 和 art-director 修订；重新运行 Step 4 无障碍检查
8. 无论用户如何选择，最终报告都包含该 BLOCKING 问题及其解决状态

**断言：**
- [ ] BLOCKING 无障碍问题不被视为建议性意见 —— 它作为阻塞项浮现
- [ ] `AskUserQuestion` 展示具体问题文本（而不只是"发现无障碍问题"）
- [ ] 用户未确认 BLOCKING 问题之前，Step 5（qa-tester）不会开始
- [ ] 提供修订路径：level-designer + art-director 可以在继续之前被退回
- [ ] 最终报告包含该无障碍问题及其解决状态
- [ ] 当 accessibility-specialist 阻塞时，art-director 已完成的产出不被丢弃

---

### 用例 5：循环关卡引用 —— 标记相邻区域依赖

**前置条件（Fixture）：**
- Step 1–3 进行中
- level-designer（Step 2）产出的布局指定了连接 "the crystal caves"（相邻区域）的出入口
- `design/levels/crystal-caves.md` 不存在 —— 水晶洞穴区域尚未设计

**输入：** `/team-level forest dungeon`

**预期行为：**
1. Step 2 —— level-designer 产出的布局包含："West exit connects to crystal-caves entry point A"
2. 编排者（或 level-designer 子代理）检查 `design/levels/` 中的 `crystal-caves.md`；文件未找到
3. 浮现依赖缺口："Level references crystal-caves as an adjacent area but `design/levels/crystal-caves.md` does not exist"
4. `AskUserQuestion` 提供选项：
   - (a) 使用占位引用继续 —— 在关卡文档中将该依赖标注为 UNRESOLVED
   - (b) 暂停，先运行 `/team-level crystal caves` 建立该区域
5. Skill 不会为满足引用而编造水晶洞穴的内容
6. 如果用户选择 (a)：汇编的关卡文档中西侧出口标记为 "→ crystal-caves (UNRESOLVED — area not yet designed)"；并在摘要报告的未决依赖小节中标记
7. 最终报告包含跨关卡未决依赖小节

**断言：**
- [ ] Skill 通过检查 `design/levels/` 检测缺失的相邻区域 —— 不假设它稍后会被创建
- [ ] Skill 不会为解决引用而编造水晶洞穴内容（世界观、布局、连接）
- [ ] `AskUserQuestion` 提供引用 `/team-level` 的"先设计水晶洞穴"选项
- [ ] 如果用户选择占位引用继续，关卡文档明确将西侧出口标记为 UNRESOLVED
- [ ] 摘要报告包含列出未解决引用的跨关卡未决依赖小节
- [ ] 循环或前向引用不会导致 Skill 死循环或崩溃

---

## 协议合规性

- [ ] 每个步骤转换处使用 `AskUserQuestion` —— 用户批准后流水线才前进
- [ ] 所有文件写入通过 Task 委托给子代理 —— 编排者不直接调用 Write 或 Edit
- [ ] 遵循 Error Recovery Protocol：浮现 → 评估 → 提供选项 → 部分报告
- [ ] Step 4 的代理（art-director、accessibility-specialist）按 skill 规格并行启动
- [ ] 即使代理 BLOCKED，也始终产出部分报告
- [ ] 无障碍 BLOCKING 问题在签核前浮现，并需要用户明确确认
- [ ] 结论为 COMPLETE / BLOCKED 之一
- [ ] 末尾给出后续步骤：`/design-review`、`/dev-story`、`/qa-plan`

---

## 覆盖说明

- Step 1 中的 narrative-director 和 world-builder 可以顺序或并行执行 —— skill 规格
  会启动两者，但不强制要求同时启动；覆盖并行 Step 1 需要
  显式的时序断言前置条件。
- 受阻 world-builder 用例（用例 2）中的"缩小范围重试"选项 ——
  重试行为本身未做深入测试；其完整路径与用例 2 及其他 team-* 规格中
  覆盖的代理受阻模式类似。
- systems-designer（Step 3）受阻场景未单独测试；适用相同的 Error Recovery
  Protocol，该模式已由用例 2 验证。
- Step 4 的并行顺序（art-director 先于或后于 accessibility-specialist 完成）
  不影响结果 —— 无论顺序如何，两者都必须在 Step 5 之前返回。
- 关卡文档 slug 约定（参数 → 文件名）由用例 1 隐式测试
  （`forest dungeon` → `forest-dungeon.md`）；多词 slug 化的边缘情况（特殊
  字符、超长名称）未覆盖。
