---
name: gate-check
description: "验证是否准备好推进到下一个开发阶段。生成 PASS/CONCERNS/FAIL 裁决，包含具体的阻塞项和所需工件。当用户说'我们准备好进入 X 了吗'、'可以推进到生产阶段吗'、'检查是否可以开始下一阶段'、'通过关卡'时使用。"
argument-hint: "[target-phase: systems-design | technical-setup | pre-production | production | polish | release] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Task, AskUserQuestion
---


# 阶段关卡验证

本技能验证项目是否准备好推进到下一个开发阶段。它检查所需的工件、质量标准以及阻塞项。

**与 `/project-stage-detect` 的区别**：该技能是诊断性的（"我们在哪个阶段？"）。本技能是规范性的（"我们准备好推进了吗？"并给出正式裁决）。

## 生产阶段（7 个）

项目依次经历以下阶段：

1. **概念（Concept）** — 头脑风暴，游戏概念文档
2. **系统设计（Systems Design）** — 映射系统，编写 GDD
3. **技术设置（Technical Setup）** — 引擎配置，架构决策
4. **预制作（Pre-Production）** — 原型制作，垂直切片验证
5. **制作（Production）** — 功能开发（Epic/Feature/Task 跟踪活跃）
6. **打磨（Polish）** — 性能优化，游戏测试，修复 Bug
7. **发布（Release）** — 发布准备，认证

**当关卡通过时**，将新的阶段名称写入 `production/stage.txt`（单行，例如 `Production`）。这将立即更新状态行。

---

## 1. 解析参数

**目标阶段：** `$ARGUMENTS[0]`（留空 = 自动检测当前阶段，然后验证下一个过渡）

同时确定审查模式（reivew mode）（一次性确定，本次运行的所有关卡复用）：
1. 如果传入了 `--review [full|lean|solo]` → 使用该值
2. 否则读取 `production/review-mode.txt` → 使用该值
3. 否则 → 默认为 `lean`

注意：在 `solo` 模式下，主管的衍生调用（CD-PHASE-GATE、TD-PHASE-GATE、PR-PHASE-GATE、AD-PHASE-GATE）被跳过——关卡检查仅进行工件存在性检查。在 `lean` 模式下，所有四位主管仍然运行（阶段关卡正是 lean 模式的目的）。

- **带参数**：`/gate-check production` — 验证是否准备好进入该特定阶段
- **无参数**：使用与 `/project-stage-detect` 相同的启发式方法自动检测当前阶段，然后**在运行前与用户确认**：

  使用 `AskUserQuestion`：
  - 提示："检测到阶段：**[当前阶段]**。正在运行 [当前] → [下一阶段] 的关卡检查。是否正确？"
  - 选项：
    - `[A] 是 — 运行此关卡`
    - `[B] 否 — 选择其他关卡`（如果选择，显示第二个小部件，列出所有关卡选项：Concept → Systems Design、Systems Design → Technical Setup、Technical Setup → Pre-Production、Pre-Production → Production、Production → Polish、Polish → Release）
  
  未提供参数时，不可跳过此确认步骤。

---

## 2. 阶段关卡定义

### 关卡：概念 → 系统设计

**所需工件：**
- [ ] `design/gdd/game-concept.md` 存在且有内容
- [ ] 核心支柱已定义（在概念文档或 `design/gdd/game-pillars.md` 中）
- [ ] `design/gdd/game-concept.md` 中存在视觉标识锚点（Visual Identity Anchor）部分（来自头脑风暴阶段 4 的美术总监输出）

**推荐（非阻塞）：**
- [ ] 概念原型存在于 `prototypes/` 中，并附带显示 PROCEED 裁决的 REPORT.md
      （`/prototype [core-mechanic]`）——跳过此步骤意味着 GDD 可能会为一个未经试玩验证的想法编写。如果概念已通过其他方式证明可行，则可接受。

**质量检查：**
- [ ] 游戏概念已经过评审（`/design-review` 裁决不是 MAJOR REVISION NEEDED）
- [ ] 核心循环已描述并理解
- [ ] 目标受众已确定
- [ ] 视觉标识锚点包含一条视觉规则和至少 2 条支持性视觉原则

---

### 关卡：系统设计 → 技术设置

**所需工件：**
- [ ] 系统索引存在于 `design/gdd/systems-index.md`，至少列举了 MVP 系统
- [ ] 所有 MVP 层级的 GDD 存在于 `design/gdd/` 中，并分别通过 `/design-review`
- [ ] `design/gdd/` 中存在跨 GDD 审查报告（来自 `/review-all-gdds`）

**质量检查：**
- [ ] 所有 MVP GDD 通过单独的设计审查（8 个必需部分，无 MAJOR REVISION NEEDED 裁决）
- [ ] `/review-all-gdds` 裁决不是 FAIL（跨 GDD 一致性和设计理论检查通过）
- [ ] `/review-all-gdds` 标记的所有跨 GDD 一致性问题已解决或明确接受
- [ ] 系统依赖关系已在系统索引中映射，且双向一致
- [ ] MVP 优先级层级已定义
- [ ] 未标记过时的 GDD 引用（较早的 GDD 已更新以反映后续 GDD 中的决策）

---

### 关卡：技术设置 → 预制作

**所需工件：**
- [ ] 引擎已选择（CLAUDE.md 中的技术栈不是 `[CHOOSE]`）
- [ ] 技术偏好已配置（`.claude/docs/technical-preferences.md` 已填充）
- [ ] 美术圣经存在于 `design/art/art-bible.md`，至少包含第 1-4 部分（视觉标识基础）
- [ ] `docs/architecture/` 中至少有 3 条架构决策记录（ADR），涵盖基础层系统（场景管理、事件架构、存档/读档）
- [ ] 引擎参考文档存在于 `docs/engine-reference/[engine]/`
- [ ] 测试框架已初始化：`tests/unit/` 和 `tests/integration/` 目录存在
- [ ] CI/CD 测试工作流存在于 `.github/workflows/tests.yml`（或等效文件）
- [ ] 至少存在一个示例测试文件以确认框架可用
- [ ] 主架构文档存在于 `docs/architecture/architecture.md`
- [ ] 架构可追溯性索引存在于 `docs/architecture/requirements-traceability.md`
- [ ] `/architecture-review` 已运行（审查报告文件存在于 `docs/architecture/` 中）
- [ ] `design/accessibility-requirements.md` 存在且已提交无障碍层级
- [ ] `design/ux/interaction-patterns.md` 存在（交互模式库已初始化，即使是最简形式）

**质量检查：**
- [ ] 架构决策覆盖核心系统（渲染、输入、状态管理）
- [ ] 技术偏好已设置命名约定和性能预算
- [ ] 无障碍层级已定义并记录（即使是"基础"也可接受——未定义则不行）
- [ ] 至少已开始一个屏幕的 UX 规范（通常在技术设置阶段设计主菜单或核心 HUD）
- [ ] 所有 ADR 均包含**引擎兼容性部分**并标注引擎版本
- [ ] 所有 ADR 均包含**解决的 GDD 需求部分**并明确链接 GDD
- [ ] 无 ADR 引用 `docs/engine-reference/[engine]/deprecated-apis.md` 中列出的 API
- [ ] 所有高风险引擎领域（根据 VERSION.md）已在架构文档中明确处理或标记为未解决的问题
- [ ] 架构可追溯性矩阵**无基础层空白**（在预制作之前，所有基础需求必须有 ADR 覆盖）

**ADR 循环依赖检查**：对于 `docs/architecture/` 中的所有 ADR，读取每条 ADR 的"ADR 依赖"或"依赖于"部分。构建依赖关系图（ADR-A → ADR-B 表示 A 依赖于 B）。如果检测到任何循环（例如 A→B→A 或 A→B→C→A）：
- 标记为 **FAIL**："检测到循环 ADR 依赖：[ADR-X] → [ADR-Y] → [ADR-X]。循环存在时两者均无法达到已接受状态。移除一条'依赖于'边以打破循环。"

**引擎验证**（首先读取 `docs/engine-reference/[engine]/VERSION.md`）：
- [ ] 触及训练截止后引擎 API 的 ADR 被标记为知识风险：高/中
- [ ] `/architecture-review` 引擎审计显示未使用弃用 API
- [ ] 所有 ADR 使用相同的引擎版本（无过时的版本引用）

---

### 关卡：预制作 → 制作

**所需工件：**
- [ ] 垂直切片存在于 `prototypes/` 中，并附带 REPORT.md（运行 `/vertical-slice`）——**推荐，非阻塞**；如果缺失，标记为关注意见（CONCERNS）
- [ ] 第一个冲刺计划存在于 `production/sprints/`
- [ ] 美术圣经已完成（全部 9 个部分），且 AD-ART-BIBLE 签收裁决记录在 `design/art/art-bible.md` 中
- [ ] 实体清单存在于 `design/assets/entity-inventory.md`（推荐——运行无参数的 `/asset-spec`，从 GDD 和美术圣经协作生成）
- [ ] 系统索引中的所有 MVP 层级 GDD 已完成
- [ ] 主架构文档存在于 `docs/architecture/architecture.md`
- [ ] `docs/architecture/` 中至少有 3 条覆盖基础层决策的 ADR
- [ ] 所有基础层和核心层的 ADR 状态为"已接受"（而非"提议"）——在管辖 ADR 被接受之前，故事无法解除阻塞
- [ ] 控制清单存在于 `docs/architecture/control-manifest.md`
      （由 `/create-control-manifest` 从已接受的 ADR 生成）
- [ ] `production/epics/` 中定义了史诗，至少包含基础层和核心层史诗
      （使用 `/create-epics layer: foundation` 和
      `/create-epics layer: core` 创建，然后对每个史诗运行
      `/create-stories [epic-slug]`）
- [ ] 垂直切片构建存在且可玩（不仅是范围定义）——**推荐，非阻塞**；如果缺失，标记为关注意见
- [ ] 垂直切片已完成至少 1 次有记录的试玩——**推荐，非阻塞**；如果缺失，标记为关注意见
- [ ] 垂直切片试玩报告存在于 `production/playtests/` 或等效位置——**推荐，非阻塞**；如果缺失，标记为关注意见
- [ ] 关键屏幕的 UX 规范存在：主菜单、核心玩法 HUD（位于 `design/ux/`）、暂停菜单
- [ ] HUD 设计文档存在于 `design/ux/hud.md`（如果游戏有游戏内 HUD）
- [ ] 所有关键屏幕的 UX 规范已通过 `/ux-review`（裁决为 APPROVED 或已接受的 NEEDS REVISION）

**质量检查：**
- [ ] **核心循环乐趣已验证**——试玩数据确认核心机制是有趣的，而不仅仅是功能性的。明确检查垂直切片试玩报告。
- [ ] UX 规范覆盖 MVP 层级 GDD 中的所有 UI 需求部分
- [ ] 交互模式库记录了关键屏幕中使用的模式
- [ ] `design/accessibility-requirements.md` 中的无障碍层级已在所有关键屏幕 UX 规范中得到处理
- [ ] 冲刺计划引用 `production/epics/` 中的真实故事文件路径
      （不仅仅是 GDD——故事必须嵌入 GDD 需求 ID 和 ADR 引用）
- [ ] **垂直切片已完成**，而不仅仅是确定了范围——构建展示完整的端到端核心循环。至少一个完整的[开始 → 挑战 → 解决]周期可运行。
- [ ] 架构文档在基础层或核心层没有未解决的未决问题
- [ ] 所有 ADR 都有标注引擎版本的引擎兼容性部分
- [ ] 所有 ADR 都有 ADR 依赖部分（即使所有字段都是"无"）
- [ ] 手动验证确认 GDD、架构和史诗之间的一致性
      （如果最近未运行，运行 `/review-all-gdds` 和 `/architecture-review`）
- [ ] **核心幻想已传达**——至少有一位试玩者独立描述了与核心系统 GDD 中玩家幻想部分相符的体验（无需提示）。

**垂直切片验证**（仅当垂直切片已构建时才运行这些检查）：
- [ ] 有人在没有开发者指导的情况下通关了核心循环
- [ ] 游戏在开始游戏的前 2 分钟内传达了该做什么
- [ ] 垂直切片构建中不存在关键的"乐趣阻断"Bug
- [ ] 核心机制交互感觉良好（这是主观检查——询问用户）

> **垂直切片的裁决规则：**
> - **切片已构建且任意验证项为否** → 裁决自动为 FAIL。损坏或无趣的垂直切片不应推进到制作阶段。
> - **切片未构建（跳过）** → 降级为关注意见（CONCERNS），而非 FAIL。明确提示风险："在未经验证的垂直切片情况下推进，会增加后期设计转向的风险。建议在投入完整制作范围之前先进行验证。"由用户决定。
> - 跳过是单人开发或时间受限情况下的合理选择。交付损坏的切片则不是。

---

### 关卡：制作 → 打磨

**所需工件：**
- [ ] `src/` 中有活跃的代码，组织成子系统
- [ ] GDD 中的所有核心机制已实现（对照 `design/gdd/` 与 `src/` 交叉引用）
- [ ] 主要玩法路径可端到端游玩
- [ ] `tests/unit/` 和 `tests/integration/` 中存在测试文件，覆盖逻辑和集成类故事
- [ ] 本次冲刺的所有逻辑类故事在 `tests/unit/` 中有对应的单元测试文件
- [ ] 冒烟检查已运行，裁决为 PASS 或 PASS WITH WARNINGS——报告存在于 `production/qa/`
- [ ] QA 计划存在于 `production/qa/`（由 `/qa-plan` 生成），覆盖本次冲刺或最终制作冲刺
- [ ] 至少有一个 QA 计划存在于 `production/qa/` 覆盖此制作阶段——如果缺失，运行 `/qa-plan`（关注意见——建议性，非阻塞）
- [ ] QA 签收报告存在于 `production/qa/`（由 `/team-qa` 生成），裁决为 APPROVED 或 APPROVED WITH CONDITIONS
- [ ] `production/playtests/` 中至少有 3 次不同的试玩记录
- [ ] 试玩报告涵盖：新手体验、中期游戏系统和难度曲线
- [ ] 游戏概念中的乐趣假设已明确验证或修订

**质量检查：**
- [ ] 测试通过（通过 Bash 运行测试套件）
- [ ] 任何 Bug 跟踪器或已知问题中无严重/阻塞性 Bug
- [ ] 核心循环按设计运行（与 GDD 验收标准比较）
- [ ] 性能在预算范围内（检查 technical-preferences.md 中的目标）
- [ ] 试玩结果已审查，关键乐趣问题已解决（不仅仅是记录）
- [ ] 不存在"困惑循环"——游戏中没有超过 50% 的试玩者卡住且不知道原因的点
- [ ] 难度曲线与难度曲线设计文档（如果存在 `design/difficulty-curve.md`）匹配
- [ ] 所有已实现的屏幕有对应的 UX 规范（无"在代码中设计"的屏幕）
- [ ] 交互模式库是最新的，包含实现中使用的所有模式
- [ ] 无障碍合规性已根据 `design/accessibility-requirements.md` 中提交的层级验证

---

### 关卡：打磨 → 发布

**所需工件：**
- [ ] 里程碑计划中的所有功能已实现
- [ ] 内容已完成（设计文档中引用的所有关卡、资产、对话都存在）
- [ ] 本地化字符串已外部化（`src/` 中无硬编码的面向玩家的文本）
- [ ] QA 测试计划存在（`/qa-plan` 输出在 `production/qa/` 中）
- [ ] QA 签收报告存在（`/team-qa` 输出——APPROVED 或 APPROVED WITH CONDITIONS）
- [ ] 所有必须有的故事测试证据都存在（逻辑/集成类：测试文件通过；视觉/感觉/UI 类：签收文档在 `production/qa/evidence/` 中）
- [ ] 冒烟检查在发布候选构建上干净通过（PASS 裁决）
- [ ] 与上一个冲刺相比无测试回归（测试套件完全通过）
- [ ] 平衡数据已审查（已运行 `/balance-check`）
- [ ] 发布检查清单已完成（已运行 `/release-checklist` 或 `/launch-checklist`）
- [ ] 商店元数据已准备（如适用）
- [ ] 变更日志 / 补丁说明已起草

**质量检查：**
- [ ] 完整 QA 测试回合由 qa-lead 签收
- [ ] 所有测试通过
- [ ] 在所有目标平台上达成性能目标
- [ ] 无已知的严重、高或中等级别 Bug
- [ ] 基础无障碍已覆盖（如适用：按键重映射、文本缩放）
- [ ] 所有目标语言的本地化已验证
- [ ] 法律要求已满足（EULA、隐私政策、年龄分级，如适用）
- [ ] 构建可干净地编译和打包

---

## 3. 运行关卡检查

**在运行工件检查之前**，如果存在 `docs/consistency-failures.md`，请读取它。提取其领域与目标阶段匹配的条目（例如，如果检查系统设计 → 技术设置，提取经济、战斗或任何 GDD 领域的条目；如果检查技术设置 → 预制作，提取架构、引擎领域的条目）。将这些作为上下文携带——目标领域中重复出现的冲突模式需要对这些特定检查进行更严格的审查。

对于目标关卡中的每个项目：

### 工件检查
- 使用 `Glob` 和 `Read` 验证文件存在且有实质内容
- 不只要检查存在性——验证文件有真实内容（不仅仅是模板标题）
- 对于代码检查，验证目录结构和文件数量

**系统设计 → 技术设置关卡的跨 GDD 审查检查**：
使用 `Glob('design/gdd/gdd-cross-review-*.md')` 查找 `/review-all-gdds` 报告。
如果没有文件匹配，将"跨 GDD 审查报告存在"工件标记为 **FAIL** 并突出显示："在 `design/gdd/` 中未找到 `/review-all-gdds` 报告。在推进到技术设置之前运行 `/review-all-gdds`。"
如果找到文件，读取它并检查裁决行：FAIL 裁决表示跨 GDD 一致性检查失败，必须在推进之前解决。

### 质量检查
- 对于测试检查：如果配置了测试运行器，通过 `Bash` 运行测试套件
- 对于设计审查检查：`Read` GDD 并检查 8 个必需部分
- 对于性能检查：`Read` technical-preferences.md 并与 `tests/performance/` 中的任何性能分析数据或最近的 `/perf-profile` 输出进行比较
- 对于本地化检查：`Grep` 搜索 `src/` 中的硬编码字符串

### 交叉引用检查
- 将 `design/gdd/` 文档与 `src/` 实现进行比较
- 检查架构文档中引用的每个系统都有对应的代码
- 验证冲刺计划引用真实的工作项

---

## 4. 协作评估

对于无法自动验证的项目，**询问用户**：

- "我无法自动验证核心循环运行良好。是否已经过试玩测试？"
- "未找到试玩报告。是否进行过非正式测试？"
- "性能分析数据不可用。是否要运行 `/perf-profile`？"

**切勿对无法验证的项目假设为 PASS。** 将它们标记为需要手动检查（MANUAL CHECK NEEDED）。

---

## 4b. 主管小组评估

**在衍生任何主管之前应用审查模式：**
- `solo` → 跳过所有四位主管。在输出中注明："主管小组已跳过——单人模式。关卡裁决基于工件和质量检查。"继续到阶段 5。
- `lean` → 衍生所有四位主管（阶段关卡始终在 lean 模式下运行——这是它们的目的）。
- `full` → 正常衍生所有四位主管。

（审查模式已在阶段 1 中确定。在此处使用该已存储的值。）

在生成最终裁决之前，通过 Task 使用 `.claude/docs/director-gates.md` 中的并行关卡协议，将四位主管作为**并行子代理**衍生。同时发出所有四个 Task 调用——不要在开始下一个之前等待一个完成。

**并行衍生：**

1. **`creative-director`** — 关卡 **CD-PHASE-GATE**（`.claude/docs/director-gates.md`）
2. **`technical-director`** — 关卡 **TD-PHASE-GATE**（`.claude/docs/director-gates.md`）
3. **`producer`** — 关卡 **PR-PHASE-GATE**（`.claude/docs/director-gates.md`）
4. **`art-director`** — 关卡 **AD-PHASE-GATE**（`.claude/docs/director-gates.md`）

向每位主管传递：目标阶段名称、存在的工件列表以及该关卡定义中列出的上下文字段。

**收集所有四个响应，然后呈现主管小组摘要：**

```
## 主管小组评估

创意总监：  [READY / CONCERNS / NOT READY]
  [反馈]

技术总监： [READY / CONCERNS / NOT READY]
  [反馈]

制作人：   [READY / CONCERNS / NOT READY]
  [反馈]

美术总监： [READY / CONCERNS / NOT READY]
  [反馈]
```

**应用于裁决：**
- 任何主管返回 NOT READY → 裁决至少为 FAIL（用户可通过明确确认覆盖）
- 任何主管返回 CONCERNS → 裁决至少为 CONCERNS
- 所有四位 READY → 有资格获得 PASS（仍受第 3 节的工件和质量检查约束）

---

## 5. 输出裁决

```
## 关卡检查：[当前阶段] → [目标阶段]

**日期**：[date]
**检查者**：gate-check 技能

### 所需工件：[X/Y 存在]
- [x] design/gdd/game-concept.md — 存在，2.4KB
- [ ] docs/architecture/ — 缺失（未找到 ADR）
- [x] production/sprints/ — 存在，1 个冲刺计划

### 质量检查：[X/Y 通过]
- [x] GDD 有 8/8 个必需部分
- [ ] 测试 — 失败（tests/unit/ 中有 3 个失败）
- [?] 核心循环试玩 — 需要手动检查

### 阻塞项
1. **无架构决策记录** — 在进入制作阶段前运行 `/architecture-decision` 创建一条
   覆盖核心系统架构的 ADR。
2. **3 个测试失败** — 在推进前修复 tests/unit/ 中的失败测试。

### 建议
- [解决阻塞项的优先行动]
- [非阻塞的可选改进]

### 裁决：[PASS / CONCERNS / FAIL]
- **PASS**：所有所需工件存在，所有质量检查通过
- **CONCERNS**：存在小差距，但可在下一阶段解决
- **FAIL**：关键阻塞项必须在推进前解决
```

---

## 5a. 验证链

在阶段 5 中起草裁决后，在定稿前对其进行挑战。

**步骤 1 — 生成 5 个挑战性问题**，旨在证伪该裁决：

> **工具操作要求**：以下 5 个挑战性问题中，至少有 2 个必须通过重新读取特定文件（Read 工具）或重新运行特定检查（Grep 工具）来回答——不能仅靠反思。用 [TOOL ACTION] 标记这些题目，表示已使用工具。

对于 **PASS** 草案：
- "我通过实际读取文件验证了哪些质量检查，又有哪些是推断其通过的？"
- "是否有标记为需要手动检查（MANUAL CHECK NEEDED）的项目我在没有用户确认的情况下标记为 PASS？[TOOL ACTION] 重新扫描检查清单，查找任何 [?] 或 MANUAL CHECK 项目。"
- "我是否确认了所有列出的工件都有真实内容，而不仅仅是空标题？[TOOL ACTION] 重新读取文件并检查其是否包含非占位符内容。"
- "是否有我当作小问题排除的阻塞项实际上可能阻碍阶段成功？"
- "我最不确信的单一检查是什么，为什么？"

对于 **CONCERNS** 草案：
- "是否有任何列出的关注意见根据项目当前状态可以升级为阻塞项？"
- "该关注意见是否可在下一阶段内解决，还是会随时间累积恶化？"
- "我是否为了回避更严格的裁决而将任何 FAIL 条件软化为 CONCERNS？"
- "是否有我未检查的工件可能揭示额外的阻塞项？"
- "即使每个关注意见单独来看都是小问题，它们加在一起是否构成了阻塞性问题？"

对于 **FAIL** 草案：
- "我是否准确区分了硬性阻塞项和强烈建议？"
- "是否有任何我过于宽松的 PASS 项目？"
- "我是否遗漏了用户应该知道的任何额外阻塞项？"
- "我能否提供一条通往 PASS 的最小路径——必须改变的具体 3 件事？"
- "失败条件是否可解决，还是表明存在更深层的设计问题？"

**步骤 2 — 独立回答每个问题**。
不要引用裁决草案文本——重新检查特定文件或询问用户。

**步骤 3 — 如果需要则修订：**
- 如果任何回答揭示了遗漏的阻塞项 → 升级裁决（PASS→CONCERNS 或 CONCERNS→FAIL）
- 如果任何回答揭示了过度陈述的阻塞项 → 仅在有具体证据引用时才降级
- 如果回答一致 → 确认裁决不变

**步骤 4 — 在最终报告输出中注明验证结果：**
`验证链（Chain-of-Verification）：[N] 个问题已检查——裁决 [未变 / 从 X 修订为 Y]`

---

## 6. 通过时更新阶段

当裁决为 **PASS** 且用户确认希望推进时：

1. 将新的阶段名称写入 `production/stage.txt`（单行，无尾部换行符）
2. 这将立即更新所有未来会话的状态行

示例：如果通过了"预制作 → 制作"关卡：
```bash
echo -n "Production" > production/stage.txt
```

**写入前始终询问**："关卡已通过。我可以将 `production/stage.txt` 更新为 'Production' 吗？"

---

## 7. 结束时的下一步选项小部件

在裁决呈现且任何 stage.txt 更新完成后，使用 `AskUserQuestion` 以一个结构化的下一步提示结束。

**根据刚运行的关卡定制选项：**

对于 **systems-design PASS**：
```
关卡已通过。接下来想做什么？
[A] 运行 /create-architecture — 生成主架构蓝图和 ADR 工作计划（推荐下一步）
[B] 先设计更多 GDD — 所有 MVP 系统完成后返回此处
[C] 本次会话到此结束
```

> **systems-design PASS 的说明**：`/create-architecture` 是在编写任何 ADR 之前的必要下一步。它生成主架构文档和要编写的 ADR 优先级列表。在没有此步骤的情况下运行 `/architecture-decision` 意味着在没有蓝图的情况下编写 ADR——风险自负。

对于 **technical-setup PASS**：
```
关卡已通过。接下来想做什么？
[A] 运行 /create-control-manifest — 从已接受的 ADR 生成层级规则清单（先做这个）
[B] 运行 /vertical-slice — 构建垂直切片（在编写史诗之前执行——先验证乐趣）
[C] 先编写更多 ADR — 运行 /architecture-decision [next-system]
[D] 本次会话到此结束
```

> **technical-setup PASS 的说明**：预制作阶段故意按特定顺序设计，
> 以便在承诺详细规划之前先验证乐趣：
>
> 1. `/create-control-manifest` — 从已接受的 ADR 提取技术规则（史诗之前必需）
> 2. `/vertical-slice` — **首先**构建垂直切片，在编写史诗或故事之前
> 3. 试玩 → `/playtest-report` — 至少需要 1 次会话才能通过预制作关卡；建议 3 次以上再投入完整团队
> 4. `/ux-design [screen]` — 主菜单、核心 HUD、暂停菜单的 UX 规范（如果尚未完成）
> 5. `/create-epics layer:foundation` 然后 `/create-epics layer:core` — 乐趣验证后再规划
> 6. 对每个史诗运行 `/create-stories [epic-slug]`
> 7. `/sprint-plan new`
>
> **为什么在史诗之前先做原型？** 如果原型显示核心循环需要更改，
> 在此之前编写的史诗将部分错误。先用低成本验证乐趣，
> 然后再详细规划。这是 GDC 事后分析数据中的第一教训。

对于所有其他关卡，提供该阶段最合理的两个下一步选项，加上"到此结束"。

---

## 8. 后续行动

根据裁决，建议具体的下一步：

- **没有美术圣经？** → `/art-bible` 创建视觉标识规范
- **有美术圣经但没有资产规格？** → `/asset-spec system:[name]` 从已批准的 GDD 生成每项资产的视觉规格和生成提示
- **没有游戏概念？** → `/brainstorm` 创建一个
- **没有系统索引？** → `/map-systems` 将概念分解为系统
- **缺少设计文档？** → `/reverse-document` 或委托给 `game-designer`
- **需要小的设计变更？** → `/quick-design` 用于约 4 小时以内的变更（绕过完整的 GDD 流水线）
- **没有 UX 规范？** → `/ux-design [screen name]` 编写规范，或 `/team-ui [feature]` 进行完整流水线
- **UX 规范未审查？** → `/ux-review [file]` 或 `/ux-review all` 进行验证
- **没有无障碍需求文档？** → 运行 `/ux-design`，它会在一步中同时创建 `design/accessibility-requirements.md` 和 `design/ux/interaction-patterns.md`
- **没有交互模式库？** → `/ux-design patterns` 初始化它
- **GDD 未交叉审查？** → `/review-all-gdds`（在所有 MVP GDD 单独批准后运行）
- **跨 GDD 一致性问题？** → 修复标记的 GDD，然后重新运行 `/review-all-gdds`
- **没有测试框架？** → `/test-setup` 为你的引擎搭建测试框架
- **当前冲刺没有 QA 计划？** → `/qa-plan sprint` 在实现开始前生成一个
- **缺少 ADR？** → `/architecture-decision` 用于单个决策
- **没有主架构文档？** → `/create-architecture` 创建完整蓝图
- **ADR 缺少引擎兼容性部分？** → 重新运行 `/architecture-decision`
  或手动向现有 ADR 添加引擎兼容性部分
- **缺少控制清单？** → `/create-control-manifest`（需要已接受的 ADR）
- **缺少史诗？** → `/create-epics layer: foundation` 然后 `/create-epics layer: core`（需要控制清单）
- **史诗缺少故事？** → `/create-stories [epic-slug]`（在每个史诗创建后运行）
- **故事未准备好实现？** → `/story-readiness` 在开发者接手前验证故事
- **测试失败？** → 委托给 `lead-programmer` 或 `qa-tester`
- **没有试玩数据？** → `/playtest-report`
- **除了最低要求外没有更多试玩会话？** → 更多会话提供更可靠的信号。在投入完整团队之前，建议总共 3 次以上。使用 `/playtest-report` 来结构化结果。
- **没有难度曲线文档？** → 从 `.claude/docs/templates/difficulty-curve.md` 模板创建 `design/difficulty-curve.md`——或使用 `/quick-design "difficulty curve"` 进行引导式会话。
- **没有玩家旅程地图？** → 从 `.claude/docs/templates/player-journey.md` 模板创建 `design/player-journey.md`——或使用 `/ux-design` 阶段 2b 协作编写。
- **需要快速冲刺检查？** → `/sprint-status` 查看当前冲刺进度快照
- **性能未知？** → `/perf-profile`
- **未本地化？** → `/localize`
- **准备发布？** → `/launch-checklist`

---

## 协作协议

本技能遵循协作设计原则：

1. **先扫描**：检查所有工件和质量关卡
2. **询问未知项**：不要对无法验证的事情假设为 PASS
3. **呈现结果**：显示带有状态的完整检查清单
4. **用户决定**：裁决是建议——用户做最终决定
5. **获得批准**："我可以将此关卡检查报告写入 production/gate-checks/ 吗？"
6. **永不自动修复**：如果所需工件缺失，报告 FAIL 裁决并指出要运行的技能名称（例如"运行 `/test-setup`"）。不要创建缺失的文件或自动重新运行关卡。为获得 PASS 而创建文件违背了关卡的目的。

**切勿**阻止用户推进——裁决是建议性的。记录风险，让用户决定是否在存在关注意见的情况下继续。
