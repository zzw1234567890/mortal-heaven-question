# Active Session State

<!-- STATUS -->
Epic: presentation-layer
Feature: Sprint 13 表现层 story 创建
Task: exploration-ui 10 stories 已写入；下一步 deck-editing-ui 的 /ux-design 前置
<!-- /STATUS -->

## 当前任务

Sprint 13 表现层 story 创建推进中（2026-09-08）：

**已完成的 epic**（story 创建层面）：
- hud（8 stories，commit dcda76f + b622ff6）
- main-menu（5 stories，commit d3d6662）
- audio-manager（7 stories + hud story 008，commit b622ff6）
- combat-ui-layout（10 stories，commit be59216）
- combat-ui-interaction（9 stories，commit 92f564e）
- **exploration-ui（10 stories，本次完成，未提交）**：
  - QL-STORY-READY（qa-lead）10 BLOCKING + 9 ADVISORY 全部裁决（用户已批准）：
    - B1：回复点回复量 30%→50%（以 exploration-system.md 公式 7 为真理源，修 UI GDD 3 处）
    - B2：ap_bar_color 补 GRAY 分支（current==0 守卫优先）+恰界语义统一（0.3 黄/0.1 红）——GDD 3 处修正
    - B3：Boss 警示改「撤退视为战败——保留 50% 本局修为」（80% 为渡劫专属）；战力展示采用角色数版本（数值对比无 API 依据）——GDD+UX 共 5 处修正
    - B4：弹窗时序裁决「先移动后弹窗」（与 ADR-0014 信号流一致）；删除 GDD「先弹确认框」分支与「高亮待选」残留
    - B5：渡劫台弹窗补 GDD §4b 规格（80% 警示朱砂红）+§4c 分发表；传送节点暂缓（exploration-system #5 机制未闭合）；事件节点显式排除
    - B6：map_cleared 单一发射者（探索系统）——UX 事件表勘误（结算确认改 map_clear_acknowledged，防双重入账）
    - B7：地图选择布局以 UX 横向滚动为准（GDD 网格→横向滚动）；费用明细扩 get_map_list() 载荷（reentry_base/multiplier）
    - B8：返回恢复流（战斗/事件/商店返回节点图恢复态）+战败路径单一化（战败→DEFEAT_SCREEN→地图选择）归 story 008
    - B9：商店为 UI overlay 非场景切换（免新增 TransitionType 枚举）
    - B10：教程覆盖归 story 005
  - 10 stories：001 节点图渲染基座+R-05 性能基准（stub 最坏情况 60fps 关卡）/002 地图选择（横向滚动+重入确认）/003 节点图数据接入与六态渲染（node_type_to_icon）/004 AP 指示器（ap_bar_color 纯函数单测 BLOCKING）/005 移动交互流+教程覆盖/006 五类节点弹窗（分发表+事件节点排除断言）/007 Boss 确认与进入战斗（50% 警示）/008 通关结算+探索结束+返回恢复流（防双重入账断言）/009 辅助面板（解锁提示/状态概览/卡组查看只读）/010 峰值复测+全流程终验（11 界面闭环+双输入路径）
  - EPIC.md Stories 表+裁决落地记录已更新；index.md 已更新

## Git 状态

- 92f564e：combat-ui-interaction 9 stories（已提交）
- 工作树未提交：exploration-ui-system.md（B1/B2/B3/B4/B5/B7 修正 11 处）+ exploration-ui.md（B2/B3/B6 勘误 6 处）+ exploration-ui EPIC.md + 10 stories + index.md + active.md

## 下一步

- 提交本批变更
- deck-editing-ui：须先 `/ux-design deck-editing-ui`（其 story 将 Blocked——无 UX 规范）
- 全部 epic 有 story 后：/sprint-plan
- Sprint 13 前置 spike（非 story）：R-01 双焦点、R-06 Ogg 循环间隙（各 0.5-1 天）
- 依赖上报清单（story 实现时跟进）：
  - get_map_list() 载荷扩展 reentry_base/reentry_multiplier（story 002 依赖——Feature 层工作）
  - 传送节点机制裁决（exploration-system #5 单向/双向）→ 后补传送弹窗 story
  - 渡劫战败返回链若需新 TransitionType → 上报 ADR-0005 修订

## 全量测试基线（不变）

- Scripts: 143 / Tests: 2455 / Passing: 2454 / Pending: 1 / Failing: 0 / Asserts: 9195
