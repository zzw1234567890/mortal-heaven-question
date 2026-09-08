# Story 001: 坊市 overlay 基建与三标签页导航

> **Epic**: 卡组编辑 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/deck-editing-ui-system.md`
**Requirement**: 坊市框架 AC（§2 进入商店加载+UX 性能 AC）+ UX 规范布局/导航 AC
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（主要）；ADR-0023: 卡组编辑系统（次要——数据接口）
**ADR Decision Summary**: 场景内 Control overlay（B9 裁决沿用——非场景切换，节点图冻结）；零状态所有权（商品/卡组数据从系统读取，本 story 以 stub 接口先行）；筛选/标签页为瞬态交互状态（ADR-0031 §2.1）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 全屏 overlay Control 层；三段式布局（顶部状态条 ~80px/中央网格 ~800px/底部操作条 ~120px，1080p 基准）。

**Control Manifest Rules (this layer)**:
- Required: overlay 打开期间探索节点图输入冻结（缩放/平移/点击无效），离开即解冻
- Forbidden: UI 持有商品/卡组持久状态（stub 数据源也须走接口注入，不硬编码于场景）
- Guardrail: overlay 打开 ≤0.5s（含展开动画）；标签页切换 ≤0.2s

---

## Acceptance Criteria

*From GDD §2 + UX 规范，scoped to this story:*

- [ ] 商店节点弹窗「进入商店」确认 → 坊市 overlay 从节点位置扩散展开（0.3s），整体打开到可交互 ≤0.5s
- [ ] 三段式布局：顶部状态条（灵石余额/「🏪 坊市」标题+三标签页/卡组余量+离开按钮）、中央网格区、底部操作条
- [ ] 三标签页（买卡/散功/售卡）切换 ≤0.2s，底部操作条内容随标签页正确切换（买卡页=刷新按钮占位/散功页=费用占位/售卡页=总价占位）
- [ ] 首次进入默认「买卡」标签页
- [ ] 「离开」按钮 → overlay 淡出（~0.3s）→ 节点图解冻恢复交互
- [ ] overlay 打开期间节点图输入冻结（缩放/平移/点击均无效）
- [ ] 1280×720 下限分辨率全部元素可见不溢出（1080p 基准尺寸按比例缩放）
- [ ] stub 数据接口：商品列表/卡组快照/灵石余额/境界上限经注入接口读取（本 story 不验证数值正确性——003/004/005 验收）

---

## Implementation Notes

*Derived from ADR-0031 + UX 规范 Layout Zones:*

- overlay 容器复用 exploration-ui story 006 的 overlay 基建（事件/商店弹窗同一宿主）——协作时确认容器注册方式。
- stub 策略（exploration 002 先例）：定义 `ShopDataSource` 接口（get_inventory/get_deck_snapshot/get_balance/get_deck_limit），本 story 用 stub 实现；003/004/005 替换为系统真实 API（依赖上报项见各 story）。
- 输入冻结沿用 exploration-ui 003 的节点图冻结机制（同族模式，勿另起炉灶）。
- 标签页状态为瞬态交互状态（UI 本地字典，不写 GSM）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 卡牌详情浮窗组件
- Story 003: 买卡标签页商品网格与购买流（本 story 只留网格区占位）
- Story 004: 散功/售卡网格与操作条真实内容
- exploration-ui 006: 商店节点弹窗本体（本 story 消费其「进入商店」确认）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[UI — manual verification steps]:**

- **AC-1**: overlay 打开性能与形态
  - Setup: 探索中走到商店节点并确认进入
  - Verify: 扩散展开动画 0.3s、总打开时间 ≤0.5s、三段式布局完整、默认买卡页
  - Pass condition: 计时达标 + 布局与 UX 规范 Layout Zones 一致

- **AC-2**: 输入冻结与解冻
  - Setup: overlay 打开状态
  - Verify: 节点图缩放/平移/点击无效；点击「离开」后全部恢复
  - Pass condition: 冻结/解冻即时生效，无输入穿透

- **AC-3**: 标签页切换与 720p
  - Setup: 三标签页间切换；窗口缩至 1280×720
  - Verify: 切换 ≤0.2s、底部操作条内容随页切换、720p 无元素溢出
  - Pass condition: 双分辨率走查通过 + 签批

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/shop-overlay-foundation-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 无硬依赖（exploration-ui 003/006 的节点图冻结与 overlay 宿主为协作项，未实现时以临时容器先行）
- Unlocks: Story 003、004、005（网格区与操作条宿主）、Story 007（终验对象）
