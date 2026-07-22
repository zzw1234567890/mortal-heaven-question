# 技能测试规格：/adopt


## 技能概述 (Skill Summary)

`/adopt` 对现有项目的制品——GDD、ADR、故事 (stories)、基础设施文件和 `technical-preferences.md`——进行审计，检查其是否符合模板技能管线的格式要求。它将每个差距按严重程度（BLOCKING / HIGH / MEDIUM / LOW）分类，编写一个带编号的有序迁移计划，并在通过 `AskUserQuestion` 获得用户明确批准后写入 `docs/adoption-plan-[date].md`。

该技能与 `/project-stage-detect`（用于检查存在什么）不同。`/adopt` 检查的是存在的内容是否能真正与模板的技能配合使用。

不设总监关卡 (director gates)。该技能不会调用任何总监代理 (director agents)。

---

## 静态断言 (Structural)

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 拥有必需的前置元字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 有 ≥2 个阶段标题
- [ ] 包含严重程度等级关键词：BLOCKING、HIGH、MEDIUM、LOW
- [ ] 在编写采纳计划之前包含"May I write"或 `AskUserQuestion` 语言
- [ ] 末尾有下一步交接（例如，提议立即修复最高优先级的差距）

---

## 总监关卡检查 (Director Gate Checks)

无。`/adopt` 是一个棕地 (brownfield) 审计工具。不设总监关卡。

---

## 测试用例 (Test Cases)

### 用例 1：正常路径 (Happy Path) —— 所有 GDD 合规，无差距，状态为 COMPLIANT

**测试夹具：**
- `design/gdd/` 包含 3 个 GDD 文件；每个文件包含所有 8 个必需部分且内容完整
- `docs/architecture/adr-0001.md` 存在，包含 `## Status`、`## Engine Compatibility` 以及所有其他必需部分
- `production/stage.txt` 存在
- `docs/architecture/tr-registry.yaml` 和 `docs/architecture/control-manifest.md` 存在
- 已在 `technical-preferences.md` 中配置引擎

**输入：** `/adopt`

**预期行为：**
1. 技能输出"正在扫描项目制品..."然后静默读取所有制品
2. 报告检测到的阶段、GDD 数量、ADR 数量、故事数量
3. 阶段 2 审计：所有 3 个 GDD 均有全部 8 个部分，状态字段存在且有效
4. ADR 审计：所有必需部分均存在
5. 基础设施审计：所有关键文件均存在
6. 阶段 3：零个 BLOCKING、零个 HIGH、零个 MEDIUM、零个 LOW 差距
7. 摘要报告："无阻塞性差距——本项目与模板兼容"
8. 使用 `AskUserQuestion` 询问是否写入计划；用户选择写入
9. 采纳计划写入 `docs/adoption-plan-[date].md`
10. 阶段 7 提供下一步操作：无阻塞性差距，提供后续步骤选项

**断言：**
- [ ] 技能在呈现任何输出之前静默读取
- [ ] "正在扫描项目制品..."出现在静默读取阶段之前
- [ ] 差距计数显示 0 个 BLOCKING、0 个 HIGH、0 个 MEDIUM（或仅 LOW）
- [ ] 在写入采纳计划之前使用了 `AskUserQuestion`
- [ ] 采纳计划文件写入 `docs/adoption-plan-[date].md`
- [ ] 阶段 7 提供了具体的下一步操作（不仅仅是列表）

---

### 用例 2：不合规文档 (Non-Compliant Documents) —— GDD 缺少部分，状态为 NEEDS MIGRATION

**测试夹具：**
- `design/gdd/` 包含 2 个 GDD 文件：
  - `combat.md` —— 缺少 `## Acceptance Criteria` 和 `## Formulas` 部分
  - `movement.md` —— 所有 8 个部分均存在
- 一个 ADR（`adr-0001.md`）缺少 `## Status` 部分
- `docs/architecture/tr-registry.yaml` 不存在

**输入：** `/adopt`

**预期行为：**
1. 技能扫描所有制品
2. 阶段 2 审计发现：
   - `combat.md`：缺少 2 个部分（Acceptance Criteria、Formulas）
   - `adr-0001.md`：缺少 `## Status` —— BLOCKING 影响
   - `tr-registry.yaml`：缺失 —— HIGH 影响
3. 阶段 3 分类：
   - BLOCKING：`adr-0001.md` 缺少 `## Status`（story-readiness 会静默通过）
   - HIGH：`tr-registry.yaml` 缺失；`combat.md` 缺少 Acceptance Criteria（无法生成故事）
   - MEDIUM：`combat.md` 缺少 Formulas
4. 阶段 4 构建有序迁移计划：
   - 步骤 1（BLOCKING）：为 `adr-0001.md` 添加 `## Status` —— 命令：`/architecture-decision retrofit`
   - 步骤 2（HIGH）：运行 `/architecture-review` 以引导创建 tr-registry.yaml
   - 步骤 3（HIGH）：为 `combat.md` 添加 Acceptance Criteria —— 命令：`/design-system retrofit`
   - 步骤 4（MEDIUM）：为 `combat.md` 添加 Formulas
5. 差距预览中 BLOCKING 项以项目符号形式显示（实际文件名），HIGH/MEDIUM 以计数显示
6. `AskUserQuestion` 询问是否写入计划；批准后写入
7. 阶段 7 提议立即修复最高优先级差距（ADR 状态）

**断言：**
- [ ] BLOCKING 差距在差距预览中以显式文件名的项目符号形式列出
- [ ] HIGH 和 MEDIUM 在差距预览中以计数形式显示
- [ ] 迁移计划项按 BLOCKING 优先排序
- [ ] 每个计划项包含修复命令或手动步骤
- [ ] 在写入之前使用了 `AskUserQuestion`
- [ ] 阶段 7 提议立即改造第一个 BLOCKING 项

---

### 用例 3：混合状态 (Mixed State) —— 部分文档合规，部分不合规，生成部分报告

**测试夹具：**
- 4 个 GDD 文件：2 个完全合规，2 个存在差距（一个缺少 Tuning Knobs，一个缺少 Edge Cases）
- ADR：3 个文件——2 个合规，1 个缺少 `## ADR Dependencies`
- 故事：5 个文件——3 个有 TR-ID 引用，2 个没有
- 基础设施：所有关键文件均存在；`technical-preferences.md` 已完全配置

**输入：** `/adopt`

**预期行为：**
1. 技能审计所有制品类型
2. 审计摘要显示总数："4 个 GDD（2 个完全合规，2 个有差距）；3 个 ADR（2 个完全合规，1 个有差距）；5 个故事（3 个有 TR-ID，2 个没有）"
3. 差距分类：
   - 无 BLOCKING 差距
   - HIGH：1 个 ADR 缺少 `## ADR Dependencies`
   - MEDIUM：2 个 GDD 缺少部分内容；2 个故事缺少 TR-ID
   - LOW：无
4. 迁移计划先列出 HIGH 差距，然后按顺序列出 MEDIUM 差距
5. 包含说明："现有故事将继续工作——不要重新生成正在进行或已完成的故事"
6. `AskUserQuestion` 询问是否写入计划；批准后写入

**断言：**
- [ ] 显示每个制品的合规统计（N 个合规，M 个有差距）
- [ ] 计划中包含现有故事兼容性说明
- [ ] 无 BLOCKING 差距导致迁移计划中没有 BLOCKING 部分
- [ ] HIGH 差距先于 MEDIUM 差距出现在计划排序中
- [ ] 在写入之前使用了 `AskUserQuestion`

---

### 用例 4：未找到制品 (No Artifacts Found) —— 新项目，引导运行 /start

**测试夹具：**
- 仓库中 `design/gdd/`、`docs/architecture/`、`production/epics/` 下没有文件
- `production/stage.txt` 不存在
- `src/` 目录不存在或少于 10 个文件
- 没有 game-concept.md，没有 systems-index.md

**输入：** `/adopt`

**预期行为：**
1. 阶段 1 存在性检查未发现任何制品
2. 技能推断为"新项目 (Fresh)"——无需要迁移的棕地工作
3. 使用 `AskUserQuestion`：
   - "这看起来像一个新项目——没有发现现有制品。`/adopt` 适用于有工作需要迁移的项目。您想怎么做？"
   - 选项："运行 `/start`"、"我的制品在非标准位置"、"取消"
4. 技能停止——无论用户如何选择，都不进入审计流程

**断言：**
- [ ] 当未找到制品时使用 `AskUserQuestion`（不仅仅是纯文本消息）
- [ ] `/start` 作为一个命名选项呈现
- [ ] 问题后技能停止——不运行审计阶段
- [ ] 未写入任何采纳计划文件

---

### 用例 5：总监关卡检查 (Director Gate Check) —— 无关卡；adopt 是工具审计技能

**测试夹具：**
- 项目包含合规与不合规 GDD 的混合

**输入：** `/adopt`

**预期行为：**
1. 技能完成完整审计并生成迁移计划
2. 在任何时候都不生成总监代理
3. 输出中不出现关卡 ID（CD-*、TD-*、AD-*、PR-*）
4. 技能运行期间不调用 `/gate-check`

**断言：**
- [ ] 未调用任何总监关卡
- [ ] 未出现关卡跳过消息
- [ ] 技能在没有任何关卡裁决的情况下完成计划编写或取消

---

## 协议合规性 (Protocol Compliance)

- [ ] 在静默读取阶段之前输出"正在扫描项目制品……"
- [ ] 在呈现任何结果之前静默读取所有制品
- [ ] 在询问是否写入之前显示采纳审计摘要和差距预览
- [ ] 在写入采纳计划文件之前使用 `AskUserQuestion`
- [ ] 采纳计划写入 `docs/adoption-plan-[date].md`——而不是其他任何路径
- [ ] 迁移计划项排序：BLOCKING 优先，HIGH 其次，MEDIUM 第三，LOW 最后
- [ ] 阶段 7 始终提供单一的下一步具体操作（不是通用列表）
- [ ] 永不重新生成现有制品——仅填补现有内容中的差距
- [ ] 在任何时候都不调用总监关卡

---

## 覆盖说明 (Coverage Notes)

- `gdds`、`adrs`、`stories` 和 `infra` 参数模式缩小了审计范围；每种模式遵循与完整审计相同的模式，但仅限于该制品类型。此处不单独进行夹具测试。
- systems-index.md 的括号状态值检查（BLOCKING）是一个特殊情况，会在编写计划前触发即时修复提议；未单独测试。
- 如果 `production/review-mode.txt` 不存在，review-mode.txt 提示（阶段 6b）会在计划编写后运行；此处未单独测试。
