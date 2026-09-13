# QA 签收报告：Sprint 13（presentation-layer-complete 里程碑）

**报告日期**：2026-09-12
**由**：qa-lead（S13-7 QA 签收 story 交付物）
**Sprint 周期**：2026-09-08 至 2026-09-19
**QA 计划**：`production/qa/qa-plan-sprint-13-2026-09-08.md`
**冒烟报告**：`production/qa/smoke-2026-09-11.md`（PASS WITH WARNINGS）
**签收范围**：must-have 全量（S13-1 至 S13-6 + 本 S13-7）；should/nice-have（S13-8 至 S13-14）截至本报告日尚未启动，不属本里程碑签收范围（见 §5）

---

## 1. 判定：APPROVED WITH CONDITIONS

must-have 全部 6 个交付 story 达成 QA 计划 DoD 全部 8 项硬性条件；自动化测试 0 确认失败、0 回归；TD-006/013 视觉证据缺口已补齐并签收。判定附带 4 项遗留条件（§5），均不阻塞 presentation-layer-complete 里程碑的 gate 推进，但须在后续冲刺消化。

---

## 2. DoD 对照表（QA 计划"完成定义"逐条）

| # | DoD 条件 | 状态 | 证据来源 |
|---|---------|------|---------|
| 1 | 所有验收标准已验证（自动化结果或记录的手动证据） | ✓ | hud 001-005 全部 AC 由测试或证据文档覆盖（§4）；R-01 spike 报告 + OQ-02 关闭（hud 005 AC-2 战斗数据断言 DEFERRED 为已裁决偏差，见 §5.1） |
| 2 | Logic/Integration 测试文件存在于指定路径 | ✓ | `tests/unit/hud/` 4 文件 + `tests/integration/hud/` 5 文件（含 smoke 报告 Coverage 表 5 COVERED / 0 missing） |
| 3 | 视觉/UI 类 story 手动证据文档存在 | ✓ | 4 份证据文档归档于 `production/qa/evidence/`（notification-stack / pause-menu / cultivation-bar / lingshi-deck-counter），全部含签收行 |
| 4 | spike 报告存在且结论写入风险登记册/OQ | ✓（范围） | R-01 报告存在（S13-1 done 2026-09-08，OQ-02 关闭）；R-06/R-02/R-03 属 should-have、S13-12 性能 Profiler 递延（§5-C） |
| 5 | 冒烟检查通过（`/smoke-check sprint`） | ✓ | smoke-2026-09-11：PASS WITH WARNINGS——自动化 PASS（2598 tests / 2597 passing / 1 pending / 0 failing）、手动批全过、警告项均为范围外递延 |
| 6 | 未引入回归（既有测试全通过） | ✓ | 2455 基线零回归；1 pending 为 save_load 预期占位；realm `test_ac010` 为预存 flaky（Sprint 12 登记，非本冲刺引入，最终复跑通过） |
| 7 | 代码已审查 | ✓ | hud 004 修复链（e8fec98）；hud 005 三专家初审 CHANGES REQUIRED → 17 项修复 → 复审 APPROVED（§4.3） |
| 8 | Story 文件 `Status: Complete` | ✓ | sprint-status.yaml：13-1 至 13-6 全部 done（13-7 由本报告关闭，见 §6） |

**DoD 结论：8/8 达成。**

---

## 3. 各 Story 签收状态汇总

| Story | 名称 | 类型 | 关卡 | 测试证据 | 视觉/手动证据 | 状态 | 签收裁决 |
|-------|------|------|------|---------|--------------|------|---------|
| S13-1 | R-01 双焦点 spike | Spike | ADVISORY | — | spike 报告 + OQ-02 关闭 | done（09-08） | **签收** |
| S13-2 | hud 001 CanvasLayer 挂载与可见性 | Integration | BLOCKING | `test_hud_scene_visibility.gd` + `test_gsm_signal_binding.gd` | —（无视觉项） | done（09-09） | **签收** |
| S13-3 | hud 002 境界+修为条 | UI+Logic | BLOCKING(单元) + ADVISORY(视觉) | `test_cultivation_bar_state.gd`（单元） | `cultivation-bar-evidence.md` 8/8 通过，Approved 09-12（TD-006 补齐） | done（09-10） | **签收**（09-12 补齐后） |
| S13-4 | hud 003 灵石+卡组计数 | UI+Logic | BLOCKING(单元) + ADVISORY(视觉) | `test_lingshi_formatter.gd` + `test_deck_count_state.gd`（单元） | `lingshi-deck-counter-evidence.md` 8/8 通过，Approved 09-12（TD-013 补齐 + 负值朱砂红裁决） | done（09-10） | **签收**（09-12 补齐后） |
| S13-5 | hud 004 通知系统 | Logic | BLOCKING | `test_notification_stack.gd`（单元）+ `test_notification_request_interface.gd`（集成） | `notification-stack-evidence.md` 9/9 通过，Approved 09-11 | done（09-11） | **签收** |
| S13-6 | hud 005 暂停菜单 | UI+Integration | BLOCKING(集成) + ADVISORY(视觉) | `test_pause_menu.gd` + `test_pause_combat_state_preserved.gd` | `pause-menu-evidence.md` 15/15 通过（AC-4 10 项 + AC-5 5 项），Approved 09-11 | done（09-11） | **签收** |
| S13-7 | QA 签收（本报告） | QA | — | 全量回归 + 证据审阅 + 冒烟 | 本报告 | backlog → 由本报告关闭 | **本报告即交付物** |

---

## 4. 冲刺质量指标

### 4.1 测试规模与通过率

| 指标 | 冲刺基线（09-08） | 冒烟（09-11） | 冒烟后增量（09-12） |
|------|------------------|---------------|---------------------|
| Scripts | 143 | 152 | — |
| Tests | 2455 | 2598 | ~2599（+`test_ac004_negative_delta_shows_red_color`） |
| Passing | 2454 | 2597 | hud 集成 67/67 + 单元 77/77 复跑全绿（提交 6b20687） |
| Pending | 1 | 1（save_load 迁移占位——预期设计） | 1 |
| Failing（确认） | 0 | 0 | 0 |

本冲刺净增约 **144 个测试**（含 hud 001-005 全部 BLOCKING 文件），通过率 100%（0 确认失败）。

### 4.2 覆盖率汇总

hud epic 全部 Logic/Integration story 测试覆盖（smoke Coverage 表 5 COVERED / 0 manual missing / 1 expected-spike）。TD-006/TD-013 视觉验证缺口经 debug 宿主 `tests/manual/hud_debug.tscn`（Autoload 真实生效、GSM 原子写入路径驱动）补齐——证据质量高于原计划（真实数据链路 vs 纯脚本触发）。

### 4.3 缺陷发现与修复链

| # | 发现来源 | 缺陷/问题 | 处置 | 提交 |
|---|---------|----------|------|------|
| 1 | hud 005 三专家 code-review | 初审 **CHANGES REQUIRED**，17 项问题（含音频总线/ESC 信号/探索进度数据源等——见 2026-09-11 QL 复审记录 INAD-1/GAP-1~5 裁决链） | 17 项全修复，**复审 APPROVED** | 3274238 / 2a5f074 |
| 2 | hud 004 code-review | B-1 幽灵 Toast 对账、B-2 双层滑入（堆叠重叠）、H-1 HUD 转发 | 修复并附回归验证 | e8fec98 |
| 3 | TD-013 验证过程（09-12） | 负值 delta 仅 ± 前缀辨识度不足 | 裁决增强：负值复用朱砂红 #B3424A 警报色 + 回归测试 `test_ac004_negative_delta_shows_red_color` | 6b20687 |
| 4 | TD-006/013 验证过程 | debug 宿主两处缺陷 | 即修 | —（56ce7ea 批次） |

**质量评价**：缺陷全部在 QA 关卡内闭环，无一逃逸到冒烟后；TD-013 验证过程本身发现并修复了一个真实可用性缺陷（左移测试价值的直接体现）。

---

## 5. 遗留条件与警告（判定附带条件）

| # | 项 | 严重性 | 归属 |
|---|-----|--------|------|
| A | **主流程端到端 N/A**：启动→主菜单→新游戏→存档周期无法在完整流程验证（main-menu epic 未建）——冒烟路径 #1/#2/#6 N/A；存档链路由 SaveLoadSystem 单元/集成测试 + hud 005 mock 覆盖 | 范围外 | main-menu epic（Sprint 14 铺路目标） |
| B | **CI 未配置**：`.github/workflows/` 不存在，全量测试为本地运行——测试标准要求"推送到 main 和每个 PR 时运行"仍未满足 | 建议项 | lead-programmer / Sprint 14 |
| C | **性能 Profiler 未实测**：手动验证无可见卡顿（模糊动画流畅），但帧预算无量化数据 | 递延 | S13-12 R-03 D3D12 冒烟 spike（冲刺内应完成） |
| D | **realm `test_ac010` 预存 flaky**：Sprint 12 起间歇性失败/通过，非本冲刺引入 | 技术债 | 建议 Sprint 14 排期根治（非 hud 域，须隔离 GSM 信号时序） |

另注（非条件、已登记技术债不阻塞）：TD-007（realm_bar 信号接线零自动化覆盖）、TD-008（reduce-motion 待设置系统）、TD-009（进度条边框）、TD-011（emoji 占位图标）、TD-012（_apply_deck 集成断言）——均已在 `docs/tech-debt-register.md` 登记，按既有排期消化。

### 5.1 已裁决偏差（记录在案，非条件）

| # | 偏差 | 裁决 |
|---|------|------|
| 1 | QA 计划要求 hud 004/005 试玩笔记（`production/session-logs/playtest-sprint13-hud.md`）——独立开发模式下试玩会期与手动验证合并执行 | ADVISORY 关卡不阻塞；手动验证由证据文档全角色签收覆盖（2026-09-11） |
| 2 | hud 005 AC-2 战斗数据断言（HP/费用/牌库计数）DEFERRED——战斗数据模型尚未建模 | 用户裁决 2026-09-11 递延，归战斗数据建模 story 后补 |

### 5.2 范围澄清

S13-8 至 S13-14（R-06 spike、hud 006/007/008、R-02、R-03、audio 001）截至本报告日为 backlog。本签收判定仅覆盖 must-have 里程碑范围；上述 story 完成后须补充冒烟 + 证据归档（S13-12 完成后条件 C 自动解除）。

---

## 6. 结论与 Gate 建议

**结论**：Sprint 13 must-have 范围达成 QA 计划 DoD 8/8，零回归，证据链完整（含 TD-006/013 补齐），缺陷全闭环。判定 **APPROVED WITH CONDITIONS**（条件 §5-A~D，均不阻塞本里程碑）。

**Gate 建议**：
1. **可以进入 `/gate-check`**——presentation-layer-complete 里程碑 QA 关卡放行
2. 本报告批准后，运行 `/story-done` 关闭 S13-7
3. 建议在冲刺剩余窗口完成 S13-12（R-03 spike）以解除条件 C；S13-8 至 S13-14 按 should/nice-have 优先级推进，不阻塞 gate
