# QA 签收报告：Sprint 17
**日期**：2026-11-08
**范围**：Sprint 17（2026-11-03 至 2026-11-12）9 个 story（must 4 + should 4 + nice 1）
**权威状态源**：`production/sprint-status.yaml`（sprint: 17，updated 2026-11-08）
**冒烟输入**：`production/qa/smoke-2026-11-08.md` — **PASS WITH WARNINGS**（5 项警告）
**QA 计划**：`production/qa/qa-plan-sprint-17-2026-11-02.md`
**审查模式**：full（`production/review-mode.txt`）
**执行口径**：本报告基于自动化测试结果 + headless 启动验证 + 证据文档文档化状态整理；**本冲刺未执行任何 GUI 运行时手动走查**（与 `smoke-2026-11-02`、`smoke-2026-11-08` 同一口径）。下文「手动 QA」列的所有结论均为**未执行**，不构成已验证结论。

---

## 测试覆盖率总结

| Story | 类型 | 自动化测试（BLOCKING） | 手动 QA（ADVISORY） | 结果 |
|-------|------|------------------------|---------------------|------|
| 17-1 exploration-ui 005 节点移动交互 | Integration | PASS —— 集成 `test_node_move_interaction`（43）+ `test_node_graph_screen_forwarding`（7）+ 单元 `test_node_keyboard_navigator`（7）/ `test_node_move_overlays`（5）；exploration_ui 单元 81/81、集成 105/105 | 0/10 已走查（`node-move-interaction-evidence.md` §2） | PASS WITH CONDITIONS |
| 17-2 combat-ui-layout 007 部署面板框架 | UI（Logic 内核） | PASS —— 单元 `test_deploy_selection_state`（27）/ `test_formation_slot_layout`（14）/ `test_deploy_roster_reader`（16）+ 集成 `test_deploy_panel`（28）/ `test_deploy_panel_host`（7）/ `test_deploy_panel_sources`（19）；combat_ui 单元 152/152、集成 210/210 | 0/8 已走查（`deploy-panel-evidence.md` §2） | PASS WITH CONDITIONS |
| 17-3 exploration-ui 006 节点交互弹窗 | Integration | PASS —— 单元 `test_node_interaction_rules`（28）+ 集成 `test_node_interaction_popups`（30）/ `test_node_graph_screen_forwarding`（14，本 story 新增 7） | 0/8 已走查（`node-popups-evidence.md` §2，含 A8 帧率未测） | PASS WITH CONDITIONS |
| 17-4 combat-ui-layout 008 结算/撤退面板 | UI（Logic 内核） | PASS —— 单元 `test_settlement_rules`（47）+ 集成 `test_loot_delay_clickable`（48） | 0/10 已走查（`settlement-retreat-evidence.md` §2） | PASS WITH CONDITIONS |
| 17-5 combat-ui-interaction 001 输入锁基座 | Integration（should） | — | — | **UNSTARTED**（不占 DoD 必须项） |
| 17-6 audio 005 暂停/静音/总线控制 | Logic+Integration（should） | — | — | **UNSTARTED**（含 17-8 原子对未启动） |
| 17-7 main-menu 005 语言切换 | UI+Integration（should） | — | — | **UNSTARTED**（不占 DoD 必须项） |
| 17-8 hud 008 静音图标 F1 | UI（should，原子对） | — | — | **UNSTARTED**（不占 DoD 必须项） |
| 17-9 exploration-ui 004 AP 指示器 | UI（Logic 内核，nice） | — | — | **UNSTARTED**（不占 DoD 必须项） |

**汇总**：4 PASS WITH CONDITIONS / 0 PASS / 0 FAIL / 0 BLOCKED / 5 UNSTARTED。

**自动化全量**（`smoke-2026-11-08.md`）：
- 单元 **2433 tests / 2432 passing / 1 pending**（存量 `test_migration_chain` 占位）/ 1 orphan（存量），154 脚本，8643 asserts。
- 集成 **1004/1004 passing**，60 脚本，3847 asserts，2 orphans（存量）。
- 合并 **3437 tests / 3436 passing / 1 pending**，相对 S16 基线（3104 / 3103 / 1）**净增 333 例，零回归**。
- headless `--quit-after 180` 启动无崩溃；`CardSystem: 无法打开模板目录` 为已知预期现象（Core 层尚无卡牌资产，非本冲刺引入）。

**BLOCKING 关卡结论**：4 个 must story 的 Logic/Integration 测试证据**全部存在于 QA 计划指定路径且通过**，无 Missing Test Evidence。DoD 的硬性关卡满足。

---

## 发现的缺陷

| ID | Story | 严重性 | 状态 |
|----|-------|--------|------|
| — | 本冲刺四 must | — | **本冲刺无新提交缺陷**（走查阶段未执行，见下条解读；缺陷通道已于 2026-11-08 建立，见条件 5） |
| — | S16-3（行动力不足 tooltip 文案 / 迷雾消散 0.3s / tooltip 0.3s 浮出） | S3（缺陷风险提示，非已确认缺陷） | 待确认——QA-17-2 未执行（依赖 QA-17-1 路径） |

**关于「零缺陷」的解读（重要）**：本冲刺零缺陷提交的成因是**未执行任何运行时人工走查**，而非「验证后确认无缺陷」。四个 must 的处理路径均为「代码层锁定 → 证据文档落盘 → 走查待办」。因此本报告的裁决必须读作「自动化层无缺陷信号」，不能读作「产品层无缺陷」。

**已登记的功能性缺口（非缺陷，但真人走查必然命中，须在推进前定性）**：
| 登记号 | 内容 | 用户可见影响 |
|--------|------|--------------|
| DEBT-EUI-005-6 | 不可达点击的 toast 渲染本体未接线（HUD 未由启动流程挂载 `request_notification`） | 不可达点击**只有抖动、无文案**——17-1 AC-3 的可见部分不完整 |
| DEBT-EUI-006-2 | `ExplorationSystem` 缺 `use_action_spring()` / `rest_at_node()` | 灵泉/回复点确认后回传 0，**AP/HP 实际不恢复** |
| DEBT-CUI-008-3 | 战利品选项只透传不补足到 3 项 | 上游给 1~2 项时「三选一」退化为 1~2 项 |
| DEBT-EUI-006-4 | 灵泉确认后 AP 指示器逐格亮起未接 004 | 效果反馈缺失（前置依赖 17-9 未启动） |

---

## 裁决：APPROVED WITH CONDITIONS

**判定依据**（按 `/team-qa` 签收规则）：
- 无任何 S1 / S2 缺陷打开；无 story FAIL。
- 四个 must 的 BLOCKING 测试证据全部存在且全绿（3436/3437 passing，1 pending 为存量），零回归。
- 四个 must 的 UI 视觉走查为 **ADVISORY** 关卡（`coding-standards` 与 QA 计划 §1 明示：UI 类故事的视觉证据关卡为建议性），未签收**不构成 NOT APPROVED**。
- 但存在大量「PASS WITH NOTES」性质的问题（36 个走查条目未执行、A8 帧率未测、QA-17-1 根因未解决）——按规则落入 **APPROVED WITH CONDITIONS**。

**裁决**：**APPROVED WITH CONDITIONS —— 构建可进入下一阶段，但 QUALITY 层面存在明确未验证面，条件闭环前不得对外宣称「核心循环第二跳已验证可玩」。**

---

## 条件

1. **[走查闭环]** 四份证据文档 §2 的 36 个走查条目 + 4 个签收框全部由人工在 D3D12 窗口模式下逐项执行并填写实测结果；优先级分批见「风险评估 §2」（P0 9 项 / P1 19 项 / P2 8 项）。
2. **[性能抽查]** `node-popups-evidence.md` §2 第 8 项 A8 帧率抽查（模糊开启 ≥60fps，观察 10s）必须实测落盘；不达标按 story 006 明文记录并转入 story 010 优化，且须在下一冲刺排期表上出现。**当前该 ADVISORY 项尚未执行**。
3. **[视觉路径根因]** QA-17-1（D3D12 视觉验证路径搭建）本冲刺**未交付**，导致 S16 五个遗留证据文档仍然回填空转（`identity-select` 12 项、`map-select-screen` 12 项、`node-graph-render` 20 项、`topbar` 17 项、`cost-bar` 10 项的实际结果列与签收框全部为空）。须在下一冲刺给出明确交付日，或**显式决定放弃自动化视觉路径、改为人工逐项走查并接受工时成本**——不得第四次静默结转。
4. **[功能性缺口承接]** DEBT-EUI-005-6（toast 未接线）与 DEBT-EUI-006-2（灵泉/回复系统 API 缺失）须由 lead-programmer / 制作人指定承接 story 与档期。这两项是「UI 已交付但用户可见效果不生效」，属跨 epic 缺口，不是 UI 缺陷，但会让任何真人试玩的第一印象失真。
5. **[缺陷通道] —— 已当场闭环（2026-11-08）**：`production/qa/bugs/` 已建立，含 `README.md`（命名规则 `BUG-NNN-<kebab-slug>.md`、编号起点 `BUG-001`、缺陷报告模板、S1~S4 严重性口径）。后续走查任何 FAIL 均可直接落盘。
6. **[文档口径纠偏]** —— **已当场闭环（2026-11-08）**：① 走查项计数不一致（冒烟称「合计 37 项」，逐文档实数为 10 / 8 / 8 / 10 = **36 项**）→ `smoke-2026-11-08.md` 已改为 36 项并逐文档列出分项；② QA 专项编号漂移（`deploy-panel-evidence.md` 用「QA-17-2」指视觉走查、`node-popups-evidence.md` 用「QA-17-4」指整份走查，均与计划中 QA-17-2/QA-17-4 的真实含义不符）→ 三份证据文档的走查标记已统一改为「待 QA 走查」，签收行改为「S17 视觉走查批次」（指向本报告的 P0/P1 清单），不再占用 QA 专项编号。**残余风险**：Sprint 18 QA 计划编写时仍需明确「视觉走查」是否单列为独立 QA 专项条目。

---

## QA 视角的风险评估

### 1. 最大不确定来源：四 must 全部只有「代码层锁定」，没有一次真人点击

- 四个 must story 的 100% 判定证据来自 GUT 自动化（3436 例）+ headless 启动。
- **一次真人点击走查都没有执行**，四个 debug 宿主（`deploy_panel_debug.tscn` / `node_popup_debug.tscn` / `settlement_panel_debug.tscn`，以及节点图走查入口）已就绪但从未被运行。
- 自动化能锁定的：数值边界、信号次数、几何字段、常量一致性、控件树结构。
- 自动化**不能**锁定的、且本冲刺完全未验证的：
  - **可辨识性**——4 态图标（✓/☐/⊕/💀）在真实字体与 D3D12 渲染下是否真的可区分；朱砂红 `#B3424A` 与淡墨边框的对比度是否足够；五境界阵位布局是否真的不重叠。
  - **手感**——0.5s 延迟是「防误触」还是「拖沓」；移动动画 0.4s + 翻转 0.2s + 迷雾 0.3s 的叠加节奏；抖动 0.3s 的幅度是否被察觉。
  - **真实字体下的排版**——tooltip 按「字符数 × 12px」估算、`POPUP_SIZE` 固定 360×220、`LOOT_CELL_HEIGHT` 固定 210，三处均有「正文超 3 行可能截断」的自述边界，且从未被真实渲染验证。
  - **性能**——背景模糊走 BackBufferCopy + 着色器，A8 帧率抽查零执行。
  - **端到端可玩性**——从启动到第一场战斗结算的第二段循环，**从未被任何人在真实窗口中完整走过一次**。

结论：本报告的「APPROVED WITH CONDITIONS」在 QUALITY 维度上的真实含义是——**代码质量已锁定，产品可玩性未知**。若决策者需要向外部（发行、投资人、试玩者）交付「核心循环第二跳可玩」的结论，该结论目前**没有证据支撑**。

### 2. 推进前最小闭环清单（按优先级，具体到文档与条目）

**P0 —— 断言「核心循环可玩」所必需，共 9 项，预计 1.5~2 人时**（可在本冲刺剩余日 2026-11-09~11-11 内完成）：

| 序 | 文档 | 条目 | 验证什么 |
|---|------|------|---------|
| 1 | `node-popups-evidence.md` | §2 **#8** A8 帧率 | 模糊开启 ≥60fps（唯一性能证据，缺失则整个 17-3 的性能结论为空） |
| 2 | `node-popups-evidence.md` | §2 **#4** | 模糊 40% + 冻结/解冻真实生效 |
| 3 | `node-move-interaction-evidence.md` | §2 **#4** | 移动动画 ~0.4s、落点精确居中（手感基线） |
| 4 | `node-move-interaction-evidence.md` | §2 **#6** | 迷雾揭示 0.3s、仅邻接层显现 |
| 5 | `settlement-retreat-evidence.md` | §2 **#2** | 0.5s 延迟体感 + 金色高亮迁移 |
| 6 | `settlement-retreat-evidence.md` | §2 **#5** | 普通撤退变体默认焦点在「继续战斗」 |
| 7 | `settlement-retreat-evidence.md` | §2 **#6** | 渡劫撤退变体与普通变体一眼可辨 |
| 8 | `node-popups-evidence.md` | §2 **#2** | 五类弹窗文案与按钮在真实字体下不截断 |
| 9 | `deploy-panel-evidence.md` | §2 **#3** | 五境界阵位布局逐张对表（布局错位属高可见度问题） |

**P1 —— 视觉可交付性，共 19 项，预计 2~3 人时**（Sprint 18 Day-1 结束前）：
- `node-move-interaction-evidence.md` §2 **#1 #2 #3 #5 #7 #8**
  （#7 注意：toast 未接线，**该项只能验抖动**，须先按条件 4 决定「改预期」还是「先接线」）
- `node-popups-evidence.md` §2 **#1 #2 #3 #5 #7**
- `deploy-panel-evidence.md` §2 **#1 #2 #4 #5 #6 #7 #8**（#7 悬停协同 + #8 替换弹窗，均为交互核心）
- `settlement-retreat-evidence.md` §2 **#1 #3 #4 #9 #10**

**P2 —— 无障碍与打磨，共 8 项，预计 1 人时**（Sprint 18 中期评审前，或显式转打磨待办）：
- `node-move-interaction-evidence.md` §2 **#9**（教程 3 步）、**#10**（reduce_motion）
- `node-popups-evidence.md` §2 **#6**（reduce_motion）
- `settlement-retreat-evidence.md` §2 **#7**（战前警示文案）、**#8**（开合动画 + reduce_motion）
- 以及 P0/P1 中任何实测 FAIL 项的复测

> 备注：P2 的 reduce_motion 三项存在共同前置——`reduce_motion` 目前需宿主显式 `set_reduce_motion()` 下发，项目**尚无全局偏好读取入口**（DEBT-CUI-008-4）。走查时只能靠 debug 宿主的 `M` 键手动切换，验收口径须写明「手动切换」而非「读取用户设置」。

### 3. 若选择「带条件推进」，闭环时点建议

- **P0（9 项）**：**本冲刺剩余日（不晚于 2026-11-11）闭环**。理由：这 9 项是「核心循环第二跳可玩」的唯一证据；拖过冲刺边界即与 Sprint 18 的新增工作竞争同一批走查人力，且本冲刺回顾将失去可引用的质量结论。若 11-11 前未完成，须在 Sprint 17 回顾中显式记为「**质量证据债**」并带入 Sprint 18 的 DoD。
- **P1（19 项）**：**Sprint 18 Day-2 结束前**（若 Sprint 18 于 2026-11-13 开始，即 2026-11-14 内）。逾期则视同「视觉可交付性未验证」，Sprint 18 的冲刺评审不得将 17-1~17-4 计入「已完成验证」。
- **P2（8 项）**：**Sprint 18 中期评审前**，或与 S16 结转的 R-02 / R-05 复测合并执行（同期可用同一 debug 宿主会话，节省启动成本）。
- **条件 6（文档口径纠偏）**：Sprint 18 QA 计划编写时（Day-0）一并修正，零额外成本。
- **条件 5（缺陷通道）**：Sprint 18 开工前建立，**P0 走查一旦 FAIL 即需要它**——建议与 P0 同步、前置完成。

### 4. 待确认项（需决策者或相关角色裁定）

> 本节在报告初稿后做过一次复核：以下 6 条中第 1、5 条已在 2026-11-08 当场闭环（记为 ✅），其余 4 条仍需决策者裁定。

1. ✅ **已闭环（2026-11-08）——走查项计数**：逐文档实数为 10 / 8 / 8 / 10 = **36 项**（另 4 个签收框）。`smoke-2026-11-08.md` 已按 36 项订正并逐文档列出分项，后续一律以 36 为台账基准。
2. **S16-7 签收状态存疑（待裁定）**：`qa-signoff-sprint-16-2026-11-02.md` 表格标注「已落盘签收（`hand-arc-evidence.md`）」，但该文档 §4 签收表中 `lead-programmer`（`[ ] 待 code-review`）与 `qa-lead`（`[ ] 待签收`）**均未勾选**。而 story 006 的 `**Code Review**` 行记录「四路并行审查全闭环」——即**代码审查实际已执行，只是证据文档的签收框未回填**。裁定建议：以 story 的 Code Review 记录为准，把 `hand-arc-evidence.md` §4 的两个框补勾（S16-7 的代码审查与 QL 关卡确已完成，不构成 S16 结论下调的理由）；缺的是文档回填动作，不是审查动作。
3. **「零缺陷」的因果（待裁定）**：`production/qa/bugs/` 目录不存在。本冲刺零缺陷究竟是「代码确实稳」还是「无人走查故未发现」，现有证据**无法区分**——本报告按后者记录（见「风险评估 §1」）。
4. **QA-17-2 / QA-17-3 完成状态（待裁定）**：QA-17-2（S16-3 三条缺陷风险确认）依赖 QA-17-1，未执行；QA-17-3（tech-debt-register 补登 S15-9 四项 + audio 004 四项）——register 中 S17 相关条目（DEBT-CUI-007-1~3、DEBT-EUI-005-1~6、DEBT-CUI-008-1~5、DEBT-EUI-006-1~5）已登记，但 S15-9 / audio 004 条目未见明确标识，**须确认是否已补登**。
5. ✅ **已闭环（2026-11-08）——走查归属编号不一致**：`deploy-panel-evidence.md`（原「QA-17-2」）、`node-popups-evidence.md`（原「QA-17-4」）、`node-move-interaction-evidence.md`（原「QA-17-1」）三份文档的走查标记已统一改为「待 QA 走查」，签收行改为「S17 视觉走查批次」，指向本报告的 P0/P1 清单——不再与 QA 专项编号（QA-17-1 视觉路径搭建 / QA-17-2 三条风险确认 / QA-17-3 技债补登 / QA-17-4 帧率抽查）混用。
6. **17-1 §2 #7 的预期与实现不符（待裁定）**：预期写「节点抖动 + toast 文案」，但 §4 明确 toast 渲染本体未接线（DEBT-EUI-005-6）。走查该条时按「仅抖动」判 PASS 还是判 FAIL？建议由 lead-programmer 在条件 4（功能性缺口承接）中一并裁定：若 toast 接线排进 Sprint 18，则走查时先按「仅抖动 → PASS WITH NOTE」记录，接线后复测升为 PASS。

---

## 下一步

1. **本冲刺内（不晚于 2026-11-11）**：执行风险评估 §2 的 P0 九项走查；先建 `production/qa/bugs/`（条件 5），使 FAIL 有落盘处。
2. **同窗口内**：完成 A8 帧率实测（条件 2），记录实测值与观察条件（分辨率 / 场景 / 是否 reduce_motion）。
3. **Sprint 17 回顾**：将条件 1（走查）/ 3（QA-17-1 根因）/ 4（功能缺口承接）三项作为流程改进项登记——本冲刺的 QA 专项 4 项中，QA-17-1 与 QA-17-4 **均未交付**，是「QA 视觉路径连续第三个冲刺未解决」的事实记录。
4. **Sprint 18 Day-0**：修正条件 6 的两处文档口径；为 DEBT-EUI-005-6 / DEBT-EUI-006-2 指定承接 story。
5. **Sprint 18 Day-2 结束前**：P1 十九项闭环；其后本报告的「APPROVED WITH CONDITIONS」可升级为 APPROVED。
6. 全部条件消解后，运行 `/gate-check` 验证 `presentation-layer-complete` 里程碑推进（该里程碑为两段式，S17 为第二段）。
