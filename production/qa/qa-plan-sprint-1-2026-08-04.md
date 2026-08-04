# QA 测试计划：Sprint 1 — Foundation 层

**日期**：2026-08-04
**Sprint**：Sprint 1 — Foundation 层
**Story 数量**：23（全部 Complete）
**引擎**：Godot 4.6.3
**审查模式**：full
**冒烟检查**：PASS（来源 `production/qa/smoke-2026-08-04.md`）

---

## 范围

Sprint 1 Foundation 层 5 个 Autoload 系统：GSM、InputManager、SceneManager、SaveLoad、EventSystem。23 个 Story 全部 Status: Complete。

---

## Story 分类表

| # | Epic/Story | 类型 | 自动化测试 | 手动 QA |
|:--|:--|:--|:--|:--|
| 1-4 | gsm/001-004 | Logic | 单元测试 `tests/unit/gsm/` | 无 |
| 5 | gsm/005 | Integration | 集成测试 `tests/integration/gsm/` | 无 |
| 6-7 | input/001-002 | Logic | 单元测试 `tests/unit/input/` | 无（双焦点 GUI 推迟 Sprint 4） |
| 8-9 | input/003-004 | Integration | 单元测试 `tests/unit/input/` | 无 |
| 10-11 | scene/001-002 | Logic | 单元测试 `tests/unit/scene_manager/` | 无 |
| 12-13 | scene/003-004 | Integration | 集成测试 `tests/integration/scene_manager/` | 无 |
| 14 | save/001 | Logic | 集成测试 `tests/integration/save_load/` | 无 |
| 15 | save/002 | Integration | 单元测试 `tests/unit/save_load/` | 可选：Windows 进程崩溃场景 |
| 16-17 | save/003-004 | Integration | 单元测试 `tests/unit/save_load/` | 无 |
| 18 | save/005 | Logic | 单元测试 `tests/unit/save_load/` | 无 |
| 19-22 | event/001-004 | Logic | 单元测试 `tests/unit/event_system/` | 无 |
| 23 | event/005 | Integration | 单元+集成测试 `tests/unit|integration/event_system/` | 无 |

**分类汇总**：14 Logic, 8 Integration, 1 Logic+Integration；Visual/Feel = 0；UI = 0；Config/Data = 0 — 符合 Foundation 层预期。

---

## 自动化测试要求

- 23 个 Story 全部已有 BLOCKING 级自动化测试证据
- 测试套件：GUT 34 脚本，521 测试，520 通过，1 pending（`migration_chain` 既有待实现项，待 CURRENT_SCHEMA_VERSION >= 2）
- 1763 断言，零失败
- 无需新增测试文件

---

## 手动 QA 范围

**必做**：无（Foundation 层无 UI，自动化测试 + grep 扫描 + headless 启动已替代覆盖）

**可选最小验证**（约 30 分钟，非阻塞）：
- Windows 编辑器运行项目，确认 5 个 Autoload 按序初始化无崩溃
- 触发一次存档写入后强制结束进程，验证 .tmp 残留下次启动不受影响
- 编辑器内存面板确认 <500MB

---

## 范围外

- 真实 Godot 4.6 双焦点 GUI 行为 → 推迟至 Sprint 4 表现层
- Save-2 防病毒/磁盘满场景 → 推迟至集成里程碑
- 试玩测试 → 推迟至 Sprint 4+
- 性能基准测试、视觉保真度、平台特定渲染（Foundation 层无相关内容）

---

## 准入标准（已全部满足）

- [x] 23 个 Story 全部 Status: Complete
- [x] 冒烟检查 PASS（`production/qa/smoke-2026-08-04.md`，零失败）
- [x] BLOCKING 级测试证据 100% 存在
- [x] 两个 grep 扫描通过（`change_scene_to_file`/`change_scene_to_packed` 仅 SceneManager；`JSON.parse_string` 零实际调用）

---

## 准出标准

- [x] 冒烟检查保持 PASS（无新增回归失败）
- [x] 无 S1/S2 缺陷
- [x] ADVISORY 项已记录并明确推迟至后续 Sprint
- [ ] qa-lead 签批 QA 报告
