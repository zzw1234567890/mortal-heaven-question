# Story 008: 通关结算、探索结束与返回恢复流

> **Epic**: 探索 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/exploration-ui-system.md`
**Requirement**: 通关结算与探索结束 6 条 AC + B8 裁决新增的返回恢复流（战斗/事件/商店返回+战败路径单一化）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0014: 探索系统（主要——map_cleared/exploration_ended 信号与结算路径）+ ADR-0005（次要——场景返回）+ ADR-0031
**ADR Decision Summary**: map_cleared 由探索系统在 Boss 击败时发射（UI 为监听方——B6 裁决，UX 事件表已勘误）；结算面板「确认」只做场景切换回地图选择（map_clear_acknowledged，不得重发 map_cleared）；战败路径单一化——战败→战败结算→返回地图选择（B8 裁决）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 全屏 CLEAR 文字+奖励逐条浮现 1.0s；探索结束面板侧边滑入 0.3s；返回加载态 ~0.5s。

**Control Manifest Rules (this layer)**:
- Required: 结算数据（奖励/收集摘要）从 map_cleared/exploration_ended 信号载荷读取——UI 零数值计算
- Forbidden: 重发 map_cleared 或任何触发奖励入账的信号（入账归系统侧，B6）；结算面板期间节点图输入冻结
- Guardrail: 战败→DEFEAT_SCREEN→地图选择的场景链经 SceneManager 管线

---

## Acceptance Criteria

*From GDD 通关结算/探索结束 AC + B8 裁决，scoped to this story:*

- [ ] map_cleared 信号（探索系统发射）→ 通关结算面板弹出：通关奖励灵石+修为逐条浮现（1.0s CLEAR 动画）
- [ ] 首次通关：额外首次通关奖励显示（金色边框高亮）；非首次通关：不显示首次奖励行
- [ ] 点击奖励卡牌 → 弹出卡牌详情（卡牌系统只读）
- [ ] 首次通关奖励卡牌+卡组已满：标注「卡组已满，超限进入弃牌流程」（展示标注——A9，弃牌流程本体归卡组系统既有行为）
- [ ] 结算面板「确认」→ map_clear_acknowledged 事件 + 场景切换回地图选择（**不重发 map_cleared**——B6 防双重入账断言）
- [ ] exploration_ended 信号（battle_lost/ap_depleted/player_quit 三 reason）→ 探索结束面板：地图名+到达层数+Boss 状态+本次收集摘要
- [ ] 收集摘要为空时显示「本次探索无收获」（UX 空态）；到达 Boss 未挑战显示「Boss未挑战」提示
- [ ] 探索结束面板「返回地图选择」→ 场景切换（面板手动关闭——无自动）
- [ ] **返回恢复流（B8 归属）**：战斗胜利（非 Boss 战斗节点）/事件完成/商店离开返回节点图 → 「节点交互返回」加载态（~0.5s）→ 当前节点标记已访问+节点状态翻转动画+迷雾刷新
- [ ] **战败路径（B8 单一化）**：战败 → 战败结算画面（DEFEAT_SCREEN）→ 返回地图选择界面（不返回节点图）
- [ ] AP 归零自动结束：归零 ~1s 延迟（004 信号）→ 探索结束面板自动弹出

---

## Implementation Notes

*Derived from ADR-0014 决策 5 + B6/B8 裁决:*

- 信号绑定：`map_cleared(map_id, rewards, is_first_clear)` UI 为监听方（ADR-0014 L217）——面板内容全部来自载荷；`exploration_ended(reason, summary)` 同理。
- 防双重入账断言（单测点）：结算面板确认路径不得出现 map_cleared 发射调用（静态断言或 mock 监听计数）。
- 返回恢复流：COMBAT_TO_EXPLORE / 事件面板关闭 / 商店 overlay 关闭三种入口统一到「节点交互返回」状态——节点已访问翻转+迷雾刷新数据从探索系统查询（node_moved 已在此前发生，此处为视觉同步）。
- 战败链：combat 战败信号 → SceneManager（COMBAT→DEFEAT_SCREEN）→ 战败画面确认 → DEFEAT_SCREEN→地图选择（GAME_TO_MENU 类过渡或专用类型——按 ADR-0005 现有枚举实现，若需新类型记录上报）。
- 首次通关奖励数据：rewards.extra（ADR-0014 calculate_map_clear_rewards）；卡组满判定从卡牌系统读。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: 进入战斗方向（本 story 为返回方向）
- Story 009: 新地图解锁提示弹窗（与通关结算同时机的独立面板）
- 探索系统域: 奖励计算/入账/map_cleared 发射
- DEFEAT_SCREEN 场景本体：归战斗/结局相关 epic（本 story 只声明场景链路径）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: 通关结算数据绑定
  - Given: map_cleared(map_id, {ling_shi:50, cultivation:50, extra:...}, is_first_clear=true/false) 两种信号
  - When: 信号到达
  - Then: 首次通关显示 extra 奖励行（金边）；非首次无该行；面板数值与载荷一致（UI 未计算）
  - Edge cases: extra 为卡牌且卡组满（「超限进入弃牌流程」标注展示）

- **AC-2**: 防双重入账
  - Given: 通关结算面板打开
  - When: 点击「确认」
  - Then: map_clear_acknowledged 发射；map_cleared 发射计数为 0（mock 探索系统信号监听断言）；request_scene_change(→地图选择) 恰好一次
  - Edge cases: 双击确认（第二次无效果）

- **AC-3**: 探索结束三路径
  - Given: exploration_ended 以 battle_lost/ap_depleted/player_quit 三 reason 发射
  - When: 信号到达
  - Then: 面板内容按 reason 差异化（战败含 DEFEAT 链提示）；summary 为空显示「本次探索无收获」
  - Edge cases: 到达 Boss 未挑战（「Boss未挑战」行）

- **AC-4**: 返回恢复流
  - Given: 战斗节点胜利返回（COMBAT_TO_EXPLORE 后）
  - When: 节点图重新激活
  - Then: 当前节点已访问态翻转（绿边+✓）+ 迷雾状态与系统查询一致 + ~0.5s 加载态过渡
  - Edge cases: 商店 overlay 关闭返回（同恢复路径）；战败返回（不出现节点图——直接 DEFEAT→地图选择）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/exploration_ui/test_clear_end_return_flow.gd` — must exist and pass
- UI: `production/qa/evidence/clear-end-return-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004（AP 归零信号）、Story 007（进入战斗的返回方向）
- Unlocks: Story 009（解锁提示与结算同时机协作）、Story 010（全流程终验）
