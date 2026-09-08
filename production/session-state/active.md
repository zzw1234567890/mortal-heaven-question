# Active Session State

<!-- STATUS -->
Epic: presentation-layer
Feature: deck-editing-ui stories
Task: create-stories 完成（7 stories+8 BLOCKING 裁决落地）——下一步 /sprint-plan new（全部 epic 已有 story）
<!-- /STATUS -->

## 当前任务

`/create-stories deck-editing-ui` 已完成（2026-09-08，最后一个无 story 的 epic）：

- **7 stories 写入** `production/epics/deck-editing-ui/`：001 坊市 overlay 基建 / 002 卡牌详情浮窗（跨界面复用）/ 003 买卡+灰态判定 Logic / 004 散功售卡+选择约束 Logic / 005 卡组浏览+筛选排序 Logic（只读+历史标签）/ 006 超限弃牌+多选状态机 Logic / 007 终验
- **QL-STORY-READY 首轮 FAIL（8 BLOCKING）→ 全裁决落地**：
  - B1：出售价=拆解基准价×0.5（终裁——三文档统一，机制 GDD §3③/公式 3/调优参数/AC、ADR-0023 样例与需求表、UI GDD §4 同步）
  - B2/B3a/B3b：UI 直调分域 API（库存归 ExplorationSystem）+通知性 Cat 2b 信号；execute_sell_batch 原子批量列入依赖上报；UX 规范 Events Fired 表改写
  - B4：四处确定性逻辑提取纯函数+tests/unit/deck_editing_ui/ BLOCKING 单测（hud story-002 先例）；tests/unit/ 目录尚不存在——实现时创建
  - B5：超限弃牌仅事件入口（战利品不可能超限——UX 进入表+UI GDD 边界情况记录）
  - B6：卡组浏览补稀有度筛选（类型 7×稀有度 6 双维度——UX/GDD 同步）
  - B7：系统 API 缺口（execute_purchase/execute_sell_batch/get_sell_total/handle_overflow/库存查询）stub+上报+复验策略入各 story
  - B8：exploration-ui story 009 缩窄为探索侧入口（卡组查看实现 AC 移交 deck-editing-ui 005；「X/30」硬编码分母同修）
- **EPIC.md**：Status Blocked→Ready+Stories 表+DoD 修正（本域 9 AC+战利品对接待验项）；index.md 更新

**已完成的 epic**（story 创建层面——全部 38 epic 均有 story）：
- Foundation 5 + Core 8 + Feature 18 + Presentation 7（hud/main-menu/audio-manager/combat-ui-layout/combat-ui-interaction/exploration-ui/deck-editing-ui）

## Git 状态

- 812e09e：deck-editing-ui UX 规范（已提交）
- 工作树未提交：7 story 文件（新建）+ EPIC.md + index.md + active.md + GDD 修正（deck-editing-system.md 出售价×0.5 三处+deck-editing-ui-system.md 稀有度筛选/超限触发/境界上限）+ ADR-0023（×0.5 样例）+ UX 规范（Events Fired 改写+进入点/AC/数据表修正）+ exploration-ui story-009 缩窄

## 下一步

- 提交本批变更（create-stories deck-editing-ui）
- **`/sprint-plan new`**（全部 epic 已有 story——Presentation 层排期就绪）
- Sprint 13 前置 spike（非 story）：R-01 双焦点、R-06 Ogg 循环间隙（各 0.5-1 天）
- sprint 前置项：卡牌详情面板模式入库（story 002 交付时）
- 依赖上报清单（story 实现时跟进——deck-editing-ui 新增）：
  - execute_purchase(card_id)（B2——库存标记归 ExplorationSystem，编排归 DeckEditingSystem）
  - execute_sell_batch(card_ids)（原子批量——B3b）
  - get_sell_total(card_ids)（OQ#2 裁决求和归系统侧）
  - handle_overflow(new_cards) + confirm_overflow_discard（系统编排）
  - ExplorationSystem 库存查询/标记已售/刷新商店 API
  - get_map_list() 载荷扩展 reentry_base/reentry_multiplier（exploration-ui story 002）
  - 传送节点机制裁决（exploration-system #5 单向/双向）→ 后补传送弹窗 story
  - 渡劫战败返回链若需新 TransitionType → 上报 ADR-0005 修订

## 全量测试基线（不变）

- Scripts: 143 / Tests: 2455 / Passing: 2454 / Pending: 1 / Failing: 0 / Asserts: 9195
