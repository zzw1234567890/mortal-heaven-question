# Story 006: 手牌区弧形渲染与静态状态

> **Epic**: 战斗 UI——静态布局与角色状态卡
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 手牌交互 AC（灰显/灵能预览 2 条静态侧）+ 边界情况（0 张/满 10 溢出）+ 公式 1/2 + 敌方手牌背面区
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 圆弧公式+重叠公式纯函数单测（BLOCKING）；>7 张合成语义已裁决（间距优先+角度自适应，GDD 2026-09-07 注释）；抽牌入场动画与敌方手牌背面区归本 story（QL-STORY-READY 裁决——系统信号驱动动画锚点）。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Control 节点+自定义脚本计算弧形位置（GDD 实现建议——非 Container 自动布局）；base_y 屏高百分比 86% 响应式。

**Control Manifest Rules (this layer)**:
- Required: `hand_card_position()`/`card_overlap_offset()` 纯函数单测（含 >7 张合成语义唯一期望值）
- Forbidden: Container 自动布局手牌；硬编码弧度
- Guardrail: 卡牌渲染成本按 009a 方案（卡面走图集）

---

## Acceptance Criteria

*From GDD + UX，scoped to this story:*

- [ ] 手牌弧形渲染（圆弧公式）：单张无弧度、多张按角度分布、旋转从 -half 到 +half 单调
- [ ] >7 张堆叠：间距优先+角度自适应（合成语义按 GDD 公式 2 裁决注释）；最小间距 40% 卡宽守卫
- [ ] Z 层序：中心卡 z_index 最高（确定性规则，入纯函数单测）
- [ ] 手牌静态状态：费用不足灰显（降饱和+费用图标灰）；阶段 2 外灵能预览（60% 饱和度+🔒，可悬停不可拖）
- [ ] 手牌 0 张：显示「无手牌」提示文字；手牌满 10 抽牌溢出：卡牌从牌库直飞弃牌堆+提示文字 2s 淡出
- [ ] 抽牌入场动画：卡牌从牌库位置飞入弧形位 0.3s/张（系统信号驱动，非用户输入）
- [ ] 敌方手牌背面区：敌方角色区上方小区域显示卡背（仅动画起始位置，不可交互）
- [ ] 手牌重排动画 0.2s ease-out（手牌变更信号驱动）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：
- `hand_card_position(index, total_cards, screen_width, screen_height) -> (x, y, rotation)`——GDD 公式 1（圆弧公式）：total=0 空数组守卫、total=1 单张守卫、响应式卡宽、端点边距 20px 守恒。
- `card_overlap_offset(total_cards, card_width) -> float`——GDD 公式 2：≤7 标准 间距、>7 重叠 30%/张、40% 下限守卫。
- >7 张合成：先 overlap 求间距再压缩 arc_angle 匹配弦长（2026-09-07 裁决）——单测锁定唯一期望。
- Z 层序函数：`hand_card_z_index(index, total_cards) -> int`（中心最高）。

- 手牌状态判定（灰显/灵能预览）由阶段信号+费用数据驱动显示；拖拽/悬停/快捷键归 interaction。
- 满牌溢出：抽牌信号在满 10 张时路由为「牌库→弃牌堆」飞行动画+提示。
- 字号经共享 `font_size_responsive()`。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: 费用数据源（本 story 消费）
- interaction epic: 悬停放大 1.2×/拖拽出牌/数字键 1-7/滚轮翻页
- audio-manager epic: 抽牌/出牌音效
- 卡牌渲染本体（卡面组件）：若已有共享卡牌组件则复用，否则本 story 建立缩略卡渲染

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/combat_ui/test_hand_card_position.gd` + `test_card_overlap_offset.gd` + `test_hand_card_z_index.gd`）

- **AC-1**: 圆弧公式守卫与对称性
  - Given: total_cards 与 index
  - When: 调用 `hand_card_position()`
  - Then: total=0 → 空数组；total=1 → (中心, 0.86H, 0)；total=7 时 index 0/6 的 x 关于中心对称且 rotation 互为相反数；中心 index y 最小、rotation≈0；index=0 的 x ≥20px
  - Edge cases: 1280 宽+total=10 响应式卡宽（所有 x ∈ [20, W-20]）；total=2 → arc=6°；rotation 单调递增

- **AC-2**: 重叠公式边界
  - Given: total_cards 与 card_width
  - When: 调用 `card_overlap_offset()`
  - Then: 7 → cw+10；8 → 0.7cw；9 → 0.4cw（恰等下限）；10 → 0.4cw（下限守卫生效）
  - Edge cases: card_width 极小值（下限仍成立）

- **AC-3**: Z 层序
  - Given: index 与 total
  - When: 调用 `hand_card_z_index()`
  - Then: 中心 index 最高，向两侧递减；total 奇偶的中心定义确定且一致
  - Edge cases: total=1（z=0）、total=2（两卡同层或定义 tie-break）

- **AC-4**: >7 张合成语义
  - Given: total=8/9/10
  - When: 组合两公式计算全部卡位
  - Then: 相邻卡水平间距 == overlap 公式返回值（唯一期望锁定）；所有卡在屏内
  - Edge cases: 间距下限与屏宽约束冲突（响应式卡宽先行收缩）

**[UI — manual verification steps]:**

- **AC-5**: 弧形与状态视觉
  - Setup: 分别构造 1/3/7/8/10 张手牌；阶段 2 与阶段 2 外
  - Verify: 弧形排列平滑、8/10 张重叠可辨认；灰显（费用不足）与灵能预览（60%+🔒）两种降饱和态视觉可区分
  - Pass condition: 边缘卡可辨认、两种状态不混淆、0 张空提示、满 10 抽牌飞弃牌堆提示 2s

---

## Test Evidence

**Story Type**: UI（Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/combat_ui/test_hand_card_position.gd` + `test_card_overlap_offset.gd` + `test_hand_card_z_index.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/hand-arc-evidence.md` + sign-off（各卡数截图）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（底部条容器与共享纯函数）、Story 005（费用数据）
- Unlocks: interaction epic（拖拽/悬停/快捷键消费弧形位）
