# QA 签收报告：Sprint 2 — Core 层

**日期**：2026-08-10
**Sprint**：Sprint 2 — Core 层
**审查模式**：full
**QA 主管**：qa-lead
**冒烟检查**：PASS（来源 `production/qa/smoke-2026-08-09.md`）

---

## 测试覆盖率总结

14/14 Story 全部 COVERED。按 Epic 分组汇总：

| # | Epic/Story | 类型 | 自动化测试 | 手动 QA | 结果 |
|:--|:--|:--|:--|:--|:--|
| 1 | card/001 CardTemplate + enums | Logic | `tests/unit/card_system/test_card_template.gd` | 无 | PASS |
| 2 | card/002 CardInstance RefCounted | Logic | `tests/unit/card_system/test_card_instance.gd` | 无 | PASS |
| 3 | card/003 CardSystem 注册表异步加载 | Integration | `tests/integration/card_system/test_card_system_loading.gd` | 冒烟检查 | PASS |
| 4 | card/004 工厂 + GSM 集成 | Integration | `tests/integration/card_system/test_card_system_factory.gd` | 冒烟检查 | PASS |
| 5 | card/005 实例序列化/重组 | Integration | `tests/integration/card_system/test_card_serialization.gd` | 冒烟检查 | PASS |
| 6 | realm/001 realm_table + 查询 | Logic | `tests/unit/realm_system/test_realm_table_query.gd` | 无 | PASS |
| 7 | realm/002 压制计算 + 权重 | Logic | `tests/unit/realm_system/test_realm_calculation.gd` | 无 | PASS |
| 8 | realm/003 realm_up 编排 | Integration | `tests/integration/realm_system/test_realm_up.gd` | 冒烟检查 | PASS |
| 9 | resource/001 Autoload + 读写 API | Integration | `tests/integration/resource_system/test_resource_read_write_api.gd` | 冒烟检查 | PASS |
| 10 | resource/002 6 公式纯函数 | Logic | `tests/unit/resource_system/test_resource_formulas.gd` | 无 | PASS |
| 11 | faction/001 FACTION_LIBRARY + 查询 | Logic | `tests/unit/faction_system/test_faction_library_query.gd` | 无 | PASS |
| 12 | faction/002 场上统计 + 判定 | Integration | `tests/integration/faction_system/test_faction_field_stats_judgment.gd` | 冒烟检查 | PASS |
| 13 | 拆分 event_system.gd | Refactor | 复用 event_system 现有 14 测试文件（570→267 行重构） | grep 行数验证 | PASS |
| 14 | Autoload 顺序验证 | Task | `tests/integration/autoload/autoload_init_order_test.gd` | project.godot 手动检查 | PASS |

**分类汇总**：6 Logic + 6 Integration + 1 Refactor + 1 Task = 14；Visual/Feel = 0；UI = 0；Config/Data = 0 — 符合 Core 层预期。

**自动化测试统计**：GUT 46 脚本，808/809 通过，1 pending（`test_migrate_if_needed_multi_step`——既有状态，非本 Sprint 引入），2933 断言，零失败，运行 ~24s。

---

## 发现的缺陷

无。`production/qa/bugs/` 目录无 `BUG-*.md` 文件。

| ID | Story | 严重性 | 状态 |
|:--|:--|:--|:--|
| — | — | — | 无缺陷 |

---

## ADVISORY 项（已记录，不阻塞）

均为 S3/S4 级别，已在各 Story 的 Completion Notes 中明确推迟或结转到 Sprint 3：

1. **CardSystem AC-010 异步加载失败路径**（S3）— `THREAD_LOAD_FAILED` 分支在 GUT headless 模式下无法确定性触发。已在 `regression-checklist.md` 记录，需在 release 候选构建中手动 QA 验证。
2. **存档/读档未单独验证**（S4）— Core 层无玩家可见状态变更触发自动存档，SaveLoadSystem 已在 Sprint 1 实现，本次冒烟检查标记为 N/A。
3. **内存 <500MB 未手动检查**（S4）— Core 层 8 个 Autoload 预计远低于预算，建议后续 QA 周期在编辑器确认。
4. **game_state_manager.gd 1016 行超标**（S4，既有债务，非本 Sprint 引入）— 已结转至 Sprint 3 Story 3-9 拆分。
5. **ADR-0003 §visited_ids 生命周期文档补充**（S4）— 已结转至 Sprint 3 Story 3-11。
6. **GSM 第二层方法独立单测补齐**（S3）— 已结转至 Sprint 3 Story 3-10。

---

## 裁决：APPROVED

**裁决依据**：

- 14/14 Story 全部 Status: Complete
- 自动化测试 808/809 通过（1 pending 为既有待实现项 `migration_chain`，非本 Sprint 引入），零失败
- BLOCKING 级测试证据 100% 存在（6 Logic + 6 Integration + 1 Refactor + 1 Task 全部 COVERED）
- 冒烟检查 PASS（808/809，零失败，headless 启动无崩溃）
- 无 S1/S2 缺陷（无任何缺陷）
- ADVISORY 项均为 S3/S4，已明确推迟或结转到 Sprint 3，不构成 CONDITIONS
- Core 层无 Visual/Feel/UI 故事，无需试玩，符合预期

**条件**：无

---

## 下一步

1. **标记 Sprint 2 QA 签批** — 本报告即签批记录，更新 `production/sprints/sprint-2.md` 完成定义。
2. **进入 Sprint 3** — Core 层 4 系统（card/realm/resource/faction）已就绪，Sprint 3 可基于此构建剩余 3 系统 + 技术债。
3. **跟踪 ADVISORY 项** — 将 6 项 ADVISORY 录入后续 Sprint 的待办：
   - CardSystem AC-010 异步加载失败路径 → release 候选构建
   - 内存手动检查 → 下次 QA 周期
   - game_state_manager.gd 拆分 → Sprint 3 Story 3-9
   - ADR-0003 文档补充 → Sprint 3 Story 3-11
   - GSM 第二层方法独立单测 → Sprint 3 Story 3-10
4. **无需缺陷分类会议** — 零缺陷，无需 `/bug-triage`。
5. **无需发布清单** — 本 Sprint 为 Core 层，非发布里程碑，`/release-checklist` 不适用。

---

**签批人**：qa-lead
**签批日期**：2026-08-10