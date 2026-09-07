# Story 002: 地图选择界面

> **Epic**: 探索 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（含 Integration 入口）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/exploration-ui-system.md`
**Requirement**: 地图选择 5 条 AC + 重入确认 3 条 AC（§1/§6）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（主要）；ADR-0014: 探索系统（次要——地图列表数据源与重入经济）
**ADR Decision Summary**: 场景内 Control + 零状态所有权（地图列表/重入费用从探索系统读取，UI 不计算）；重入扣费由探索系统执行（`map_reentry_denied` 拒绝信号），UI 仅发意图。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 横向滚动卡片列表（B7 裁决——UX 布局为准）；卡片入场动画 0.3s/张。

**Control Manifest Rules (this layer)**:
- Required: 地图列表按需读取（进入界面时拉取）；重入费用总额+明细从 `get_map_list()` 载荷读取（含 `reentry_base`/`reentry_multiplier` 扩展字段——B7 裁决）
- Forbidden: UI 自行拆算费用明细（零数值计算）；UI 直接操作灵石（重入扣费归探索系统）
- Guardrail: 卡片列表横向滚动平滑（滚轮/滚动条/手柄 LB/RB）

---

## Acceptance Criteria

*From GDD 地图选择 AC + 重入确认 AC，scoped to this story:*

- [ ] 进入探索阶段加载完成后显示地图选择界面：已解锁地图彩色+可点击，未解锁灰色+🔒锁标记
- [ ] 已通关地图卡片显示「重入XX灵石」费用（数据来自 get_map_list 载荷）
- [ ] 点击已通关地图 → 弹出重入确认窗口（地图名+费用明细（基础价×倍率）+当前灵石+确认/取消）
- [ ] 灵石不足时重入确认按钮灰色不可点击+标注「灵石不足」
- [ ] 苍玄古战场已通关 → 不可重入（不显示重入弹窗/无重入入口）
- [ ] 未解锁地图悬停显示「需X境界」
- [ ] 点击未通关+境界达标地图 → 直接进入（0 灵石，迷雾汇聚加载动画 →节点图，动画归 story 003 场景切换协作）
- [ ] 顶部灵石余额显示（资源系统只读）
- [ ] 地图卡片横向滚动（滚轮/滚动条/手柄 LB/RB 三路径）
- [ ] 锁定地图卡片灰显+锁图标+悬停解锁条件（UX AC）

---

## Implementation Notes

*Derived from ADR-0031 + ADR-0014 决策 4:*

- 数据源：探索系统 `get_map_list()`（ADR-0014 L404）——本 story 依赖其载荷扩展（`reentry_base`/`reentry_multiplier`，B7 裁决）。若 Feature 层尚未实现该扩展，story 实现时以 stub 载荷先行 + 记录依赖缺口上报。
- 重入流：UI 点击「确认传送」→ 调用探索系统重入 API（意图）→ 探索系统验证扣费 → 成功则场景切换/失败（`map_reentry_denied` 信号）则 toast 提示。UI 绝不自行扣灵石。
- 横向滚动卡片列表：卡片 ~360×420px（B7 裁决）；卡片入场逐张弹出 0.3s/张。
- 显式排除声明（A4）：本 story 不做首次通关奖励预览（GDD 待解决问题 #3）、不做预计灵石显示（#5）——机制未裁决，防止验收时被当作隐性需求。
- 新地图 ⭐NEW 标记的显示归本 story（卡片渲染），解锁提示弹窗归 story 009。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: 节点图主界面（重入确认后的地图加载动画细节）
- Story 009: 新地图解锁提示弹窗（本 story 只做卡片 NEW 标记）
- 探索系统域: get_map_list() 载荷扩展实现（Feature 层工作——本 story 消费）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[UI — manual verification steps]:**

- **AC-1**: 地图卡片状态走查
  - Setup: 存档含已通关/未通关/未解锁三类地图
  - Verify: 三类卡片视觉区分（彩色/灰锁）、悬停提示、重入费用显示
  - Pass condition: 与 GDD §1 界面规则逐条一致

- **AC-2**: 重入确认流
  - Setup: 灵石充足与不足两种存档
  - Verify: 确认弹窗内容（费用明细+余额）、灵石不足按钮禁用、苍玄古战场无重入入口
  - Pass condition: 双存档路径行为正确 + 费用数字与探索系统返回值一致（非 UI 计算）

- **AC-3**: 横向滚动三路径
  - Setup: 地图数 > 横向可见数
  - Verify: 滚轮/滚动条/手柄 LB/RB 均可滚动
  - Pass condition: 三路径平滑滚动 + 卡片入场动画 0.3s/张

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/map-select-screen-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（无需——独立界面；但建议 001 先行建立渲染预算意识）
- Unlocks: Story 003（进入地图后的节点图）、Story 009（解锁提示跳转目标）
