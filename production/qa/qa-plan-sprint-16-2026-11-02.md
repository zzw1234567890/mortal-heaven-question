# QA 计划：Sprint 16（团队 QA 周期版）
**日期**：2026-11-02
**由**：/team-qa sprint 生成
**范围**：7 个已完成 story（S16-1 至 S16-7），涉及 5 个系统（identity-selection / exploration-ui / audio-manager / combat-ui-layout / hud 无关项已排除）
**引擎**：Godot 4.6.3
**Sprint 文件**：`production/sprint-status.yaml`（sprint 16，7 done + 2 backlog）

> 本计划由 qa-lead 策略评审生成，作为 /team-qa sprint 的测试计划载体。S16-8/16-9 为 backlog（nice-to-have，未实现），排除在 QA 范围外。

---

## 测试摘要

| Story | 类型 | 自动化测试证据 | 手动验证 |
|-------|------|------------------------|------------------------------|
| S16-1 身份选择 UI 场景 | UI（Logic 内核） | 需要 — `tests/unit/identity_selection_system/test_identity_unlock_gate.gd`（4 例）+ `test_menu_navigation.gd` 追加 2 例 | 手动走查 + 截图签收 |
| S16-2 地图选择界面 | UI（含 Integration 入口） | 需要 — `tests/unit/exploration_ui/test_map_select_logic.gd`（19 例） | 手动走查 + 截图签收 |
| S16-3 节点图数据接入与状态渲染 | Integration | 需要 — `tests/integration/exploration_ui/test_node_graph_render.gd` + `tests/unit/exploration_ui/test_node_state_logic.gd`（40 例） | 手动走查 + 截图签收 |
| S16-4 set_state 编排与过渡矩阵 | Logic + Integration | 需要 — `tests/unit/audio/test_state_matrix.gd`（67 例）+ `tests/integration/audio/test_scene_signal_binding.gd`（42 例）+ scene_manager 回归（72 例） | 无（自动化覆盖） |
| S16-5 顶部条三组件 | UI（Integration） | 需要 — `tests/integration/combat_ui/test_phase_indicator_signal.gd` + `test_log_phase2_autocollapse.gd` + `test_formation_zone.gd` + `test_formation_row_scale.gd`（30+ 例） | 手动走查 + 截图签收 |
| S16-6 费用栏与牌库/弃牌计数 | UI（Logic 内核） | 需要 — `tests/unit/combat_ui/test_cost_color.gd`（9 例）+ `tests/integration/combat_ui/test_cost_display.gd`（14 例） | 手动走查 + 截图签收 |
| S16-7 手牌弧形渲染 | UI（Logic 内核） | 需要 — `tests/unit/combat_ui/test_hand_card_position.gd`（11）+ `test_card_overlap_offset.gd`（7）+ `test_hand_card_z_index.gd`（7）+ `tests/integration/combat_ui/test_hand_area.gd`（12） | 已有 — `hand-arc-evidence.md` 已落盘 |

---

## 需要自动化测试

自动化测试证据已全部存在并通过（全量 3104 tests / 3103 passing / 1 pending 存量 `test_migration_chain`，零回归）。本周期无需新增自动化测试文件，仅验证既有覆盖。

---

## 手动 QA 检查清单

### S16-1 身份选择 UI 场景 — UI
**验证方法**：手动逐步走查 + 截图
**必须签收人**：ui-programmer + lead-programmer + qa-lead
**证据**：`production/qa/evidence/identity-select-evidence.md`（待补）
- [ ] 6 卡身份网格渲染完整，无缺失卡片
- [ ] 未解锁身份显示 🔒 遮罩，不可选中
- [ ] 确认弹窗两分支（确认 / 取消）行为正确
- [ ] 入场动画 0.6s 播放，reduce_motion 下直跳终态

### S16-2 地图选择界面 — UI
**验证方法**：手动逐步走查 + 截图
**必须签收人**：ui-programmer + qa-lead
**证据**：`production/qa/evidence/map-select-screen-evidence.md`（待补）
- [ ] 四态卡片视觉可区分（可选/锁定/灵石不足/已完成）
- [ ] 重入确认流：确认→扣费一致、拒绝→toast
- [ ] 灵石不足态正确显示
- [ ] 横向滚动三路径（键盘/鼠标/手柄）均可操作

### S16-3 节点图数据接入与状态渲染 — Integration
**验证方法**：手动逐步走查 + 截图
**必须签收人**：ui-programmer + lead-programmer
**证据**：`production/qa/evidence/node-graph-render-evidence.md`（待补）
- [ ] 10 类型节点图标渲染正确
- [ ] 六态视觉（迷雾/已探索/当前/完成/渡劫/精英）可区分
- [ ] 连线绘制正确，迷雾消散逻辑正确
- [ ] 悬停预览正常

### S16-5 顶部条三组件 — UI
**验证方法**：手动逐步走查 + 截图
**必须签收人**：ui-programmer + qa-lead
**证据**：`production/qa/evidence/topbar-evidence.md`（待补）
- [ ] 阶段指示器随阶段切换更新
- [ ] 阵法区 3 槽渲染正确
- [ ] 日志展开半屏不遮费用栏

### S16-6 费用栏与牌库/弃牌计数 — UI
**验证方法**：手动逐步走查 + 截图
**必须签收人**：ui-programmer + qa-lead
**证据**：`production/qa/evidence/cost-bar-evidence.md`（待补）
- [ ] 费用颜色三态（充足/不足/临时）视觉可区分
- [ ] 数字跳动 + 光粒消散动画正常
- [ ] 临时费用淡出正确
- [ ] 牌库/弃牌计数同步正确

### S16-7 手牌弧形渲染 — UI（已落盘）
**验证方法**：复核已存在证据 `production/qa/evidence/hand-arc-evidence.md`
**必须签收人**：ui-programmer + lead-programmer + qa-lead
- [x] 证据文档已存在（AC-5 走查表 + 签收表已填）

---

## 冒烟测试范围

冒烟检查已完成：`production/qa/smoke-2026-11-02.md`（verdict: PASS WITH WARNINGS）。关键路径验证：
1. 游戏启动到主菜单无崩溃 — PASS
2. 新游戏开始 — PASS
3. 身份选择→地图选择→节点图前三跳 — PASS（代码层锁定）
4. combat-ui 顶部条/费用栏/手牌 — PASS
5. audio 004 矩阵 + scene_manager — PASS
6. 存档/读档 — PASS

三条警告（ADVISORY，不阻塞 QA）：
1. 前三跳运行时端到端未手动走查（S16-3 本次才补提交）
2. 性能未单独压测
3. QA 计划 `qa-plan-sprint-16-2026-10-24.md` 第 21 行 S16-7 条目陈旧（记作 audio 005，实际 combat-ui-layout 006）

---

## 试玩要求

本次 Sprint 无需试玩会期（核心循环第一跳的"手感"验证由设计侧在后续 polish 阶段执行，本周期以代码层锁定 + UI 截图签收为准）。

---

## 范围外

- S16-8 静音图标 F1（backlog，nice-to-have，未实现）
- S16-9 语言切换（backlog，nice-to-have，未实现）
- 卡面美术本体（归资产管线，S16-7 Out of Scope 明确）

---

## 准入标准

1. 冒烟检查报告存在且为 PASS 或 PASS WITH WARNINGS — ✅ `smoke-2026-11-02.md`
2. 构建稳定（启动不崩溃）— ✅
3. 所有 must-have story 在 `sprint-status.yaml` 中 status 为 done — ✅（7/7）

## 准出标准

- 所有 7 个已完成 story 的自动化测试证据已核实通过 — ✅
- 5 个待补 UI 证据文档落盘并完成签收（或明确记录为 ADVISORY 移交）
- 冒烟三条警告记录在案（ADVISORY 移交后续）
- 签收报告裁决：APPROVED / APPROVED WITH CONDITIONS / NOT APPROVED

---

## 完成定义 — 本次 Sprint

- [x] 所有验收标准已验证（自动化测试结果通过）
- [x] 所有 Logic/Integration story 测试文件存在于指定路径
- [ ] 5 个 UI 证据文档落盘（S16-1/2/3/5/6）+ 签收（或 ADVISORY 移交）
- [x] 冒烟检查通过（PASS WITH WARNINGS）
- [x] 未引入回归（全量 3104 零回归）
- [ ] 代码已审查（各 story code-review 已闭环）
- [x] story 文件已更新为 Status: Complete（7/7）
