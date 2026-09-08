# Active Session State

<!-- STATUS -->
Epic: presentation-layer
Feature: deck-editing-ui UX 规范
Task: ux-review 修复完成（B1/A3/A4），规范 Approved——下一步 /create-stories deck-editing-ui
<!-- /STATUS -->

## 当前任务

deck-editing-ui UX 规范已完成并通过 ux-review（2026-09-08）：

- **规范**：design/ux/deck-editing-ui.md——20 条 AC、17 状态、三段式布局（坊市/卡组浏览/超限弃牌）、B6 信号归属先例沿用（UI 意图信号+系统侧持久变更）
- **ux-review 结论**：NEEDS REVISION → 3 项修复落地后 Approved：
  - B1（阻塞）：卡组浏览「出售/拆解」GDD 间矛盾裁决——只读（机制层 2026-08-30 背书）+批量出售归坊市售卡页+「拆解」统一为「出售」术语；UI 层 GDD 补边界澄清
  - A3：散功/出售二次确认弹窗补价格金额（与购买弹窗信息对齐）
  - A4：补 720p 下限分辨率 AC（对齐 exploration-ui/combat-ui 先例）
- **GDD 待解决问题裁决 3 项**：#1 悬停预览（采纳）、#2 超限弃牌出售替代（不提供）、#3 跳过按钮（归 combat-ui）
- **模式库**：3 新模式已入库（商品卡/散功选择网格/超限弃牌网格）
- **角色替换弹窗**：裁决归事件/叙事流程（Open Questions #6 记录）

**已完成的 epic**（story 创建层面）：
- hud（8 stories，commit dcda76f + b622ff6）
- main-menu（5 stories，commit d3d6662）
- audio-manager（7 stories + hud story 008，commit b622ff6）
- combat-ui-layout（10 stories，commit be59216）
- combat-ui-interaction（9 stories，commit 92f564e）
- exploration-ui（10 stories，commit 2386cb2）——QL-STORY-READY 10 BLOCKING 全裁决（B1 回复量 50%/B2 ap_bar_color GRAY/B3 Boss 警示 50%+角色数/B4 先移动后弹窗/B5 渡劫台补规格+传送暂缓/B6 map_cleared 单一发射者/B7 横向滚动+费用明细载荷/B8 返回恢复流归 008/B9 商店 overlay/B10 教程归 005）；GDD 修正 11 处+UX 勘误 6 处

## Git 状态

- 2386cb2：exploration-ui 10 stories（已提交）
- 工作树未提交：deck-editing-ui.md（新建 UX 规范，20 AC）+ deck-editing-ui-system.md（B1 边界澄清——卡组浏览只读+拆解统一术语）+ interaction-patterns.md（3 新模式：商品卡/散功选择网格/超限弃牌网格）+ active.md

## 下一步

- 提交本批变更（deck-editing-ui UX 规范 + GDD 边界澄清 + 模式库更新）
- `/create-stories deck-editing-ui`（最后一个无 story 的 epic——UX 规范前置已就绪）
- 全部 epic 有 story 后：/sprint-plan
- Sprint 13 前置 spike（非 story）：R-01 双焦点、R-06 Ogg 循环间隙（各 0.5-1 天）
- 依赖上报清单（story 实现时跟进）：
  - get_map_list() 载荷扩展 reentry_base/reentry_multiplier（exploration-ui story 002 依赖——Feature 层工作）
  - 传送节点机制裁决（exploration-system #5 单向/双向）→ 后补传送弹窗 story
  - 渡劫战败返回链若需新 TransitionType → 上报 ADR-0005 修订
  - get_sell_total(card_ids) API（deck-editing-ui OQ#2——售卡总价求和归系统侧，create-stories 时与架构确认）

## 全量测试基线（不变）

- Scripts: 143 / Tests: 2455 / Passing: 2454 / Pending: 1 / Failing: 0 / Asserts: 9195
