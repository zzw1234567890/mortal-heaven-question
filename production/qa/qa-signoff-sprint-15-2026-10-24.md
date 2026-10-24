# QA 签收报告：Sprint 15

**日期**：2026-10-24
**范围**：9 个 story（4 must + 3 should + 2 nice），5 个系统（combat-ui-layout / exploration-ui / audio-manager / main-menu / hud）+ 技术债打包项
**引擎**：Godot 4.6.3（GUT 9.6.1）
**冒烟检查**：PASS WITH WARNINGS（`production/qa/smoke-2026-10-23.md`）

---

## 测试覆盖率总结

| Story | 类型 | 自动化测试 | 手动 QA | 结果 |
|-------|------|:---:|:---:|------|
| S15-1 TD-014 根治 + TD-007/012 补齐 | Logic/测试 | PASS（CI 连续两跑绿） | — | PASS |
| S15-2 exploration-ui 001 节点图基座 + R-05 | Visual/Feel | —（性能不可自动化） | PASS（基准实测 + 主管签批） | PASS |
| S15-3 combat-ui-layout 001 布局骨架 | UI（含 Integration） | PASS | PASS（截图签收） | PASS |
| S15-4 combat-ui-layout 002 角色状态卡 | UI（Logic 内核） | PASS | PASS（截图签收） | PASS |
| S15-5 audio 002 BGM 交叉淡化 | Logic | PASS | —（听感由 R-06 spike 承接） | PASS |
| S15-6 combat-ui-layout 003 状态标记/阵亡/飘字 | UI（Integration） | PASS | PASS（录屏签收） | PASS |
| S15-7 main-menu 004 按键绑定 | UI（Logic 内核） | PASS | PASS（手动走查） | PASS |
| S15-8 hud 006 探索 HUD 信息组 | UI | PASS | PASS（截图签收） | PASS |
| S15-9 audio 003 SFX 池 | Logic | PASS | — | PASS |

自动化全量：**2921 tests / 2920 passing / 1 pending**（save_load 迁移链占位，既有）——零失败。

---

## 发现的缺陷

无。冒烟检查唯一 FAIL 项「新游戏无法开始」经根因分析确认为**预存在的文档化留桩**（`SCENE_PATHS` 中 10 个场景路径未搭建，非 sprint 15 回归，`main-menu/story-001` Completion Notes 明载 Out of Scope），降级为警告，不计为缺陷。

---

## 裁决：APPROVED WITH CONDITIONS

**条件**（ADVISORY，非阻塞——均不要求本冲刺内修复）：

1. **S15-6 Test Evidence 段口径不一致**：该段写「待录屏签收（ADVISORY）」，Completion Notes 写「签收 3/3」——证据文件 `character-state-death-evidence.md` 实际存在且签收完整。建议 story 文件 Test Evidence 段与 Completion Notes 对齐。
2. **S15-2 R-05 复测义务挂账**：R-05 为 stub 版基准关闭（p95=2.04ms / DC=90）。story 010 需以真实美术图标 + 揭雾动画复跑对照（已双登记：证据文件「复测义务登记」+ 风险登记册 R-05「残留」）。
3. **S15-9 残留 4 项 S 级建议**：补静音语义 / `_find` 反查索引 / `active_count` 与 `_active_count` 重复 / 4 余量节点用途说明——挂账至 audio story 004。已登记 Completion Notes，建议在 tech-debt-register 独立留痕。

**冒烟警告项跟进**（供 Sprint 16 规划）：
- `SCENE_PATHS` 中 10 个场景路径为占位（含 `identity_select.tscn`），「新游戏」等转场目标不可达——需「身份选择 UI 场景」及后续 feature 场景 story 落地。
- 1 个 pending 测试（save_load 迁移链占位）既有，待首次 schema 升级时实现。

---

## 下一步

构建已准备好进入下一阶段。S3/S4 级建议事项可推迟到打磨阶段处理。

按顺序推进：
1. `/retrospective` — 记录 sprint 15 复盘
2. `/gate-check` — 推进到 presentation-layer-complete 里程碑下一阶段
3. `/sprint-plan new` — 规划 sprint 16（纳入：identity_select 场景落地、R-05 复测义务、audio 004 承接项）
