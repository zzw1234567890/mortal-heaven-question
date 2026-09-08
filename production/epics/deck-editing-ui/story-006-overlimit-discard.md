# Story 006: 超限弃牌界面

> **Epic**: 卡组编辑 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（含 Logic 内核：多选状态机纯函数）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/deck-editing-ui-system.md` §6 超限弃牌界面
**Requirement**: 超限 AC（机制层 GDD 超限弃牌 3 条：获得物弹窗→弃牌流程/补偿/确认门）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（主要）；ADR-0023: 卡组编辑系统（次要——handle_overflow 编排）
**ADR Decision Summary**: 强制模态（无取消出口——确认是唯一退出路径）；UI 直调 `confirm_overflow_discard(card_ids)`（B2/B3a 裁决——handle_overflow 编排归系统侧，B7 依赖上报）；补偿金额（N×5 灵石）系统返回。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 中央模态 ~1200×800 红色警示样式；面板从顶部压下 0.3s。

**Control Manifest Rules (this layer)**:
- Required: 多选状态机提取纯函数（`tests/unit/deck_editing_ui/`）——B4 裁决（combat 002 HoverExclusionMachine 同构先例）
- Forbidden: UI 计算补偿金额（系统返回）；提供任何取消/关闭出口（强制完成取舍）
- Guardrail: 选满 N 张后确认按钮才激活；✓标记+边框高亮双编码（非仅颜色）

---

## Acceptance Criteria

*From GDD §6 + 机制层 GDD 超限弃牌 AC，scoped to this story:*

**Logic 内核（自动化单测，BLOCKING）：**
- [ ] `overflow_selection_state(deck_size, limit, selected_ids, card_id, action) → 结构` 纯函数（输入序列→状态机）：
  - 需弃数 N = deck_size - limit
  - toggle(card_id)：未选→加入；已选→移除
  - 选满 N 张后再选新卡 → 拒绝+「已达弃牌数上限」提示触发（不自动换选——与散功单选换选行为不同）
  - 确认可用 = selected.size() == N
  - 补偿预览 = N×5（系统返回值透传——纯函数仅校验一致性）
  - 边界用例：先选 3 张再取消 2 张 → 计数实时更新，确认以最终选择为准；恰好选满 → 激活；超选尝试 → 拒绝
  - 测试文件：`tests/unit/deck_editing_ui/overflow_selection_state_test.gd`（GUT）

**UI（手动验证）：**
- [ ] 触发路径：**仅事件结算**（2026-09-08 B5 裁决——战利品单次最多+1 张且卡组满时灰显，不可能超限；GDD 边界情况已同步）
- [ ] 进入前必经「你获得了以下卡牌」知情弹窗（不可跳过）→ 确认后进入弃牌界面
- [ ] 警示头部：「⚠ 卡组超限！X/上限张（超限 N 张）」+「请选择 N 张弃掉」
- [ ] 进度指示：「已选：X 张（还需选 Y 张）」实时更新+补偿预览「+Z 灵石」
- [ ] 选满 N 张后确认按钮从禁用变激活：「确认弃牌 ✓（获得 Z 灵石）」
- [ ] **无取消路径**：无关闭按钮/ESC/B 键不可退出——确认是唯一出口
- [ ] 确认 → 卡牌移除+补偿灵石入账（系统侧执行）+返回事件流程继续
- [ ] 红色警示面板从顶部压下 0.3s（减少动态开启时瞬时出现）
- [ ] 多选 ✓ 标记弹入+计数/补偿数字滚动 ≤0.2s

---

## Implementation Notes

*Derived from ADR-0023 handle_overflow + B5/B7 裁决:*

- **依赖上报（stub+复验——B7 裁决）**：`DeckEditingSystem.handle_overflow(new_cards)` 及系统侧弃牌确认入口（`confirm_overflow_discard`——名称以 Feature 层实现为准）**尚未实现**（非桩，完全不存在）。本 story 以 stub 先行：stub 提供触发（测试钩子构造超限状态）+确认接收（记录调用参数）；真实编排就绪后复验全链路（获得物弹窗时序归 handle_overflow 流程①——系统编排 UI 展示，边界：弹窗 UI 归本 story，编排顺序归系统侧）。
- 触发验证用测试钩子（debug 注入超限状态），不依赖事件系统 UI 完成。
- 「你获得了以下卡牌」弹窗复用模式库-确认对话框骨架（非确认语义——信息展示型变体）。
- 与事件面板的叠加层级：事件面板之上强制模态（UX Navigation Position）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: 坊市 overlay（非宿主——本界面独立模态）
- Story 007: 终验（全流程闭环）
- Feature 层: handle_overflow 系统编排实现（依赖上报项）
- 战利品→超限链路：**不存在**（B5 裁决——已从触发路径删除，GDD 边界情况已记录原因）
- 事件面板 UI：触发源（事件系统 epic 范围）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Logic — automated test specs]:**

- **AC-1**: 多选状态机
  - Given: deck_size=32, limit=30（N=2）
  - When: toggle(A)→toggle(B)→toggle(C)
  - Then: A、B 选中，C 被拒绝（已达上限提示），确认可用（selected=2=N）
  - Edge cases: toggle(A)再toggle(A)→取消；选3取消2→最终计数以确认时为准；(35,20)→N=15；(deck_size==limit)→不应触发本界面（防御断言）

**[UI — manual verification steps]:**

- **AC-2**: 强制流程走查
  - Setup: 测试钩子注入 32/30 超限状态
  - Verify: 知情弹窗不可跳过→弃牌界面；无任何取消出口（ESC/B/关闭按钮均无效）；选满激活；确认后返回事件流程
  - Pass condition: 唯一出口验证通过 + 走查签批

- **AC-3**: 进度与补偿数字
  - Setup: 超限 2 张存档
  - Verify: 已选/还需计数实时更新、补偿预览（系统返回 10 灵石）、确认按钮文案含金额
  - Pass condition: 数字与系统返回一致（UI 未计算）+ 动画时序达标

---

## Test Evidence

**Story Type**: UI（含 Logic 内核）
**Required evidence**:
- `tests/unit/deck_editing_ui/overflow_selection_state_test.gd` — 必须存在且通过（BLOCKING）
- `production/qa/evidence/overlimit-discard-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None（独立模态组件；Story 002 详情浮窗可选接入）
- Unlocks: Story 007（终验含超限闭环）
