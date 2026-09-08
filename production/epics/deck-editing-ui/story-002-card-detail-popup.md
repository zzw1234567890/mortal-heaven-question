# Story 002: 卡牌详情浮窗（跨界面复用组件）

> **Epic**: 卡组编辑 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/deck-editing-ui-system.md` §7 卡牌详情浮窗
**Requirement**: 详情浮窗 AC（GIVEN 卡牌详情浮窗，WHEN 点击卡牌，THEN 显示卡名、效果、稀有度、来源）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 零状态所有权（卡牌模板数据从卡牌系统读取）；组件场景化复用（同一 .tscn 被坊市/卡组浏览/后续 combat-ui 引用）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 悬停触发（坊市商品/卡组网格）+ 点击触发（卡组浏览）双入口；弹出动画从卡牌位置放大展开 0.2s。

**Control Manifest Rules (this layer)**:
- Required: 详情数据按需读取（打开时从卡牌系统模板查询，不缓存于组件）
- Forbidden: 组件持有任何持久游戏状态
- Guardrail: 浮窗宽度 ~320px（280-400 调优）；悬停 300ms 延迟显示（模式库-悬停提示先例）

---

## Acceptance Criteria

*From GDD §7 + UX 规范，scoped to this story:*

- [ ] 浮窗内容完整：卡名/稀有度颜色条（rarity_color 五档）/类型标签/费用/效果全文/流派标签/本命加成提示/获得来源（第X章·XX事件，可选）
- [ ] 悬停触发：鼠标悬停 300ms 弹出；移开立即消失（无延迟）
- [ ] 点击触发：卡组浏览中点击卡牌弹出，关闭按钮/ESC/点击外部关闭
- [ ] 弹出动画：从卡牌位置放大展开 0.2s（「减少动态」开启时瞬时出现）
- [ ] 键盘聚焦等效：Tab 聚焦到卡牌时同样展开详情（非鼠标专用——无障碍先例）
- [ ] 定位：跟随目标卡牌偏移放置，不遮挡被悬停卡牌本体
- [ ] 互斥：同时最多一个详情浮窗（悬停互斥——模式库先例）
- [ ] 焦点锁定：浮窗打开期间 Tab 循环在浮窗内

---

## Implementation Notes

*Derived from ADR-0031 + GDD §7 + 模式库:*

- 模式归属（A2 裁决记录）：本组件为「卡牌详情面板」的规范实现（模式库缺口表 L854 高优先级项）——combat-ui-interaction story 002 的手牌悬停详情**不复用**本组件的容器与交互（其 HoverExclusionMachine 四面板体系独立），但**卡牌数据结构**（模板字段）保持同源（卡牌系统 API）。模式入库为 sprint 前置项（ADR-0031 §6）。
- rarity_color 映射（GDD 公式节）：1白#CCCCCC/2蓝#4488FF/3紫#AA44FF/4金#FFAA00/5暗金#FF4400——提取为纯函数供复用。
- 悬停延迟与互斥逻辑沿用模式库-悬停提示规格。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003/005: 本组件的接入（商品卡悬停/卡组网格点击）——本 story 只交付组件与自测场景
- combat-ui-interaction 002: 战斗手牌悬停详情（独立体系，仅数据结构同源）
- combat-ui 牌库/弃牌面板的战斗标注变体（UX OQ#3 开放项）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[UI — manual verification steps]:**

- **AC-1**: 内容完整性
  - Setup: 自测场景放置白/蓝/紫/金/暗金五张卡
  - Verify: 五档稀有度色条正确、效果全文/标签/本命/来源逐字段显示
  - Pass condition: 与 GDD §7 线框逐字段一致

- **AC-2**: 触发与关闭双路径
  - Setup: 悬停模式与点击模式两个测试卡
  - Verify: 300ms 延迟弹出/移开即失；点击弹出/ESC/外部点击三路径关闭；键盘聚焦等效
  - Pass condition: 双触发+三关闭路径全部生效 + 互斥（同时仅一个浮窗）

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/card-detail-popup-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None（独立组件；卡牌系统模板 API 已存在）
- Unlocks: Story 003（商品悬停详情）、Story 005（卡组网格点击详情）
