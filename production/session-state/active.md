# Active Session State

<!-- STATUS -->
Epic: presentation-layer
Feature: Sprint 13 表现层 story 创建
Task: combat-ui-interaction 9 stories 已写入；下一步 exploration-ui /create-stories
<!-- /STATUS -->

## 当前任务

Sprint 13 表现层 story 创建推进中（2026-09-07）：

**已完成的 epic**：
- hud（8 stories，commit dcda76f + b622ff6）
- main-menu（5 stories，commit d3d6662）
- audio-manager（7 stories + hud story 008，commit b622ff6）
- combat-ui-layout（10 stories，commit be59216）
- **combat-ui-interaction（9 stories，本次完成，未提交）**：
  - QL-STORY-READY（qa-lead）12 BLOCKING + 10 ADVISORY 全部裁决（用户已批准）：
    - B1：GDD 边界情况行 527 MOUSE_FILTER_IGNORE → STOP 修正（与 §12 统一）
    - B2：结束出牌按钮——底部条右侧新增（layout story 005 补渲染位 AC+实现说明+Out of Scope）
    - B3/B4/B5：备战面板瞬态+一次性提交（battle_start config 扩展含 character_ids+layout）+替换对象=已选角色列表二次选择
    - B6：战斗日志交互并入 story 008（更名「牌库/弃牌堆/日志面板交互」）
    - B7：005/006 补键盘/手柄路径（EPIC DoD 全覆盖）
    - B8：数字键需目标卡=临时目标选择态（Enter 确认/ESC 取消）；>7 张映射=当前可见窗口 7 张
    - B9：ESC 仲裁归 story 001（锁栈 get_current_lock 判定最上层面板）
    - B10：story 001 收窄为基建基座（stub 弹窗验证机制，实际接入归 002-008，009 回归）
    - B11：撤退按钮 GAMEPLAY+ANIMATION 锁期间排队执行
    - B12：loot_skipped 补 GDD AC（含二次确认）
    - GDD 边界澄清补充二（9 条）已写入 combat-ui-system.md；§12 表费用栏/牌库行统一为点击展开
  - 9 stories：001 输入锁栈基座+ESC 仲裁（resolve_esc_target 纯函数）/002 悬停预览互斥（HoverExclusionMachine）/003 拖拽出牌（DragStateMachine+结束出牌点击）/004 键盘手柄（digit_key_to_card_index 窗口映射）/005 目标选择（TargetSelectionModel 空真语义）/006 备战交互流（DeployDraftModel 瞬态零写入断言）/007 结算撤退持久写入（委托链断言）/008 牌库弃牌日志面板/009 峰值复测+拖拽 D3D12 烟雾（R-01/R-02 收口）
  - EPIC.md Stories 表+裁决落地记录已更新；index.md 已更新

## Git 状态

- be59216：combat-ui-layout 10 stories（已提交）
- 工作树未提交：combat-ui-system.md（边界澄清补充二+B1/B12 修正+§12 统一）+ combat-ui-layout/story-005（结束出牌按钮补记）+ combat-ui-interaction EPIC.md + 9 stories + index.md + active.md

## 下一步

- 提交本批变更
- `/create-stories exploration-ui`（下一 epic——GDD exploration-ui-system.md APPROVED，UX 规范已有）
- deck-editing-ui：须先 `/ux-design deck-editing-ui`（其 story 将 Blocked）
- 全部 epic 有 story 后：/sprint-plan
- Sprint 13 前置 spike（非 story）：R-01 双焦点、R-06 Ogg 循环间隙（各 0.5-1 天）

## 全量测试基线（不变）

- Scripts: 143 / Tests: 2455 / Passing: 2454 / Pending: 1 / Failing: 0 / Asserts: 9195
