# QA 签收报告：Sprint 3 — Core 层剩余系统 + 技术债

**日期**：2026-08-15
**Sprint**：Sprint 3 — Core 层剩余系统 + 技术债
**审查模式**：full
**QA 主管**：qa-lead
**冒烟检查**：PASS WITH WARNINGS（来源 `production/qa/smoke-2026-08-15.md`）

---

## 测试覆盖率总结

12/12 Story 全部完成。按类型汇总：

| # | Story | 类型 | 自动化测试 | 手动 QA | 结果 |
|:--|:--|:--|:--|:--|:--|
| 1 | 3-1 /create-stories + 契约盘点 | Task | — | — | PASS |
| 2 | 3-2 CostSystem 费用上限/恢复/临时加成 | Integration | `tests/integration/cost_system/test_cost_system_basic.gd` | 冒烟检查 | PASS |
| 3 | 3-3 双重信号路径 | Logic | `tests/unit/cost_system/test_cost_signals.gd` | 无 | PASS |
| 4 | 3-4 StatusEffect 8 阶段管线 | Integration | `tests/integration/status_effect/test_status_lifecycle.gd` | 冒烟检查 | PASS |
| 5 | 3-5 叠加规则 + 免疫 + 20 上限 | Logic | `tests/unit/status_effect/test_stacking_immunity.gd` | 无 | PASS |
| 6 | 3-6 snapshot 导出 + 暂挂/恢复 | Integration | `tests/integration/status_effect/test_snapshot_suspend.gd` | 冒烟检查 | PASS |
| 7 | 3-7 SchoolSystem 纯查询接口 | Logic | `tests/unit/school_system/test_school_library_query.gd` | 无 | PASS |
| 8 | 3-8 5 流派增益 + 不可驱散 | Logic | `tests/unit/school_system/test_school_effects.gd` | 无 | PASS |
| 9 | 3-9 拆分 game_state_manager.gd | Refactor | 复用 `tests/unit/gsm/` + `tests/integration/gsm/` 6 文件 | grep 行数验证 | PASS |
| 10 | 3-10 GSM 第二层方法单测 | Task | `tests/unit/gsm/test_second_layer_methods.gd` | 无 | PASS |
| 11 | 3-11 ADR-0003 visited_ids 文档 | Doc | — | 文档审查 | PASS WITH NOTES |
| 12 | 3-12 Feature 层预创建 | Planning | — | — | PASS |

**分类汇总**：4 Logic + 3 Integration + 1 Refactor + 2 Task + 1 Doc + 1 Planning = 12；Visual/Feel = 0；UI = 0；Config/Data = 0 — 符合 Core 层预期。

**自动化测试统计**：GUT 62 脚本，1145/1146 通过，1 pending（`test_migrate_if_needed_multi_step`——save_load 多步迁移首版有意延后，非本 Sprint 引入），0 失败，运行 ~44s。

---

## 发现的缺陷

无。`production/qa/bugs/` 目录不存在，零 `BUG-*.md` 文件。

| ID | Story | 严重性 | 状态 |
|:--|:--|:--|:--|
| — | — | — | 无缺陷 |

---

## ADVISORY 项（已记录，不阻塞）

均为 S3/S4 级别或预期架构决策，已明确推迟或结转：

1. **1 orphan 测试内存泄漏**（S4）— `tests/unit/input/test_gsm_sync.gd` 的 `test_ac006_no_own_signals_declared` 遗留一个未释放的 `input_manager.gd` Node 实例。input 系统为 Foundation 层（Sprint 1/2 范围），非 Sprint 3 引入。
2. **RealmSystem(#11) / SchoolSystem(#19) 未注册 Autoload**（S4，预期架构决策）— `project.godot` 仅注册到 StatusEffectSystem(#10)。realm/school story 明确「本 Story 仅实现代码，Autoload 注册在项目配置阶段完成」，待 Feature 层 CombatSystem #20 接入时一并注册。
3. **CardSystem 模板目录缺失**（S4，预期现象）— `res://assets/cards/templates/` 不存在，CardSystem push_error「无法打开模板目录」。Core 层本无卡牌资产（Sprint 2 亦记录同类）。

### 本次 QA 周期修复的遗留项（已解决，不结转）

1. **8 个 cost_system 既有测试失败**（修复于 QA 前）— 根因：6 个信号计数（`_track_signal` 连接晚于 `init_for_battle`）+ 2 个 lambda 按值捕获 int 失效 + 2 个 battle=null 时 `_set_battle_cost` 额外 push_warning。修复后 cost_system 套件 74/74 通过。
2. **3 个 EventSystem 测试文件 parse error**（修复于冒烟检查）— 28 个测试从未被 GUT 加载：`test_event_trigger.gd`（10 处 `:=` 动态分派推断失败）、`test_resolve_option.gd`（8 处同类）、`test_select_event.gd`（续行缩进）。修复后 EventSystem 套件 190/190 通过，全量测试从 1117 提升到 1145 通过。
3. **ADR-0003 / chain_handler.gd 措辞矛盾**（修复于文档审查）— `get_chain_event()` 文档与 docstring 声称「不修改 visited_ids」，但链结束分支 a/b/d 实际执行 `clear()`。已修正为「不追加、不发射信号，但链结束分支会 `clear()`」。

---

## 裁决：APPROVED

**裁决依据**：

- 12/12 Story 全部 Status: Complete
- 自动化测试 1145/1146 通过（1 pending 为既有待实现项 `migration_chain`，非本 Sprint 引入），零失败
- BLOCKING 级测试证据 100% 存在（4 Logic + 3 Integration + 1 Refactor + 2 Task 全部 COVERED）
- 冒烟检查 PASS WITH WARNINGS（1145/1146，零失败，headless 启动无崩溃）
- 无 S1/S2 缺陷（无任何缺陷）
- Story 3-11 文档审查 PASS WITH NOTES——唯一 notes 为措辞矛盾，已在本次周期内修复，不构成 CONDITIONS
- ADVISORY 项均为 S3/S4 或预期架构决策，不阻塞
- Core 层无 Visual/Feel/UI 故事，无需试玩，符合预期

**条件**：无

---

## 下一步

1. **标记 Sprint 3 QA 签批** — 本报告即签批记录，更新 `production/sprints/sprint-3.md` 完成定义（冒烟检查、QA 签收两项勾选）。
2. **剩余完成定义项** — `代码已审查并合并` 需 `/code-review` + git 提交（待用户明确指示提交）。
3. **进入 Sprint 4** — Core 层 8 系统（card/cost/status-effect/realm/faction/resource/school + GSM）已就绪，Feature 层（战斗系统为 MVP 关键路径）可启动。
4. **跟踪 ADVISORY 项** — 3 项录入后续 Sprint 待办：
   - orphan 测试内存泄漏 → 下次 input 系统触碰时修复
   - RealmSystem/SchoolSystem Autoload 注册 → Feature 层 CombatSystem 接入时
   - CardSystem 模板目录 → 卡牌资产管线建立时
5. **无需缺陷分类会议** — 零缺陷，无需 `/bug-triage`。
6. **无需发布清单** — 本 Sprint 为 Core 层，非发布里程碑，`/release-checklist` 不适用。

---

**签批人**：qa-lead
**签批日期**：2026-08-15
