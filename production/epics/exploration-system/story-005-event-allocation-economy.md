# Story 005: 事件节点分配 + 经济计算

> **Epic**: exploration-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-29

## Context

**GDD**: `design/gdd/exploration-system.md`
**Requirement**: `TR-explore-005`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0014（探索系统 — Autoload + GSM 主存储 + 程序化 DAG 生成 + 信号驱动子系统委托）
**ADR Decision Summary**: 探索系统自身执行经济计算（重入费、境界差额惩罚、通关奖励），灵石扣除通过 GSM 委托。地图经济三重安全阀：重入费公式 10 + 境界差额惩罚公式 6 + 永久免费地图。事件节点不分配具体事件——到达时才触发（防 SL）。

**Engine**: Godot 4.6 | **Risk**: MEDIUM（经济公式实现 + 三种结算路径）
**Engine Notes**: 经济计算为纯数学运算（floor/maxi），无引擎 API 依赖。GSM 第二层方法用于资源写入。均为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: 事件节点不分配具体事件——仅记录 event_pool —— 来源: ADR-0014
- **Required**: 灵石扣除通过 GSM 委托——不绕过 GSM 直接操作资源 —— 来源: ADR-0014
- **Forbidden**: 在事件节点生成时分配具体事件 —— 来源: ADR-0014

---

## Acceptance Criteria

*From ADR-0014 §决策 4 地图经济模型 + §决策 5 探索结束结算 + GDD §公式 5/6/10/11:*

- [ ] **AC-001**: `calculate_reentry_cost(map_id)` 返回传送费——首次进入 0，后续按公式 10 计算（base × multiplier，硬上限 3.0x）
- [ ] **AC-002**: `calculate_map_clear_rewards(map_id, is_first_clear, player_realm, map_max_realm)` 返回 {ling_shi, cultivation, extra}——灵石受境界差额惩罚，修为不受
- [ ] **AC-003**: `realm_gap_penalty(player_L, map_max_L)` 返回 float——gap<=0→1.0, gap>=1→max(0.1, 1.0-gap*0.3)
- [ ] **AC-004**: `collect_resource(resource_type, amount)` 累积到 map_states[current_map].collected_*
- [ ] **AC-005**: `_flush_map_state(map_id)` 将 collected_* 转移到 GSM player.* 域（通过 GSM 原子方法）
- [ ] **AC-006**: `end_exploration(reason)` 三种结算路径——BOSS_DEFEATED 全额+通关奖励、BATTLE_LOST 修为保留 50%、AP_DEPLETED 全额保留
- [ ] **AC-007**: 永久免费地图（PERMANENT_FREE_MAPS）重入费始终 0
- [ ] **AC-008**: 事件节点 event_pool 在 generate_map 时已填充——到达时通过 resolve_node 发射 event_node_reached 信号（防 SL 机制验证）

---

## Implementation Notes

*Derived from ADR-0014 §决策 4 地图经济模型 + §决策 5 探索结束结算 + GDD §公式:*

1. **文件位置**: `src/feature/exploration_system.gd` — 新增经济计算 + 资源收集 + 结算方法
2. **重入费用公式 10**:
   - base = {LOW:30, MEDIUM:60, HIGH:100, VERY_HIGH:150}
   - entry_count <= 1 → 0（首次免费）
   - multiplier = min(1.0 + (entry_count-2)*0.5, 3.0)
   - cost = floor(base * multiplier)
3. **境界差额惩罚公式 6**:
   - gap = player_L - map_max_L
   - gap <= 0 → 1.0（无惩罚）
   - gap >= 1 → max(0.1, 1.0 - gap*0.3)（每级 -30%，保底 10%）
4. **通关奖励公式 5+6**:
   - base = {LOW:{ls:50,cult:50}, MEDIUM:{ls:100,cult:80}, HIGH:{ls:200,cult:120}, VERY_HIGH:{ls:300,cult:150}}
   - ling_shi = floor(base.ls * penalty)
   - cultivation = base.cult（不受惩罚）
5. **永久免费地图**: const Dictionary，key=map_id，value=realm_level
6. **资源收集**: collect_resource(type, amount) 更新 map_states[current_map].collected_*
7. **结算路径**: end_exploration(EndReason) — BOSS_DEFEATED/BATTLE_LOST/AP_DEPLETED
8. **_flush_map_state**: 将 collected_ling_shi / collected_cultivation 转移到 GSM player.* 域

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: move_to_node / resolve_node 节点推进——本 Story 只处理经济和结算
- **UI**: 地图选择界面渲染、费用确认弹窗——UI Epic 职责
- **敌人阵容生成**: AISystem.create_enemy_roster——通过回调注入
- **商店交易**: 商店节点库存购买逻辑——CardSystem/ResourceSystem 职责

---

## QA Test Cases

*From ADR-0014 §验证标准 + GDD §公式 5/6/10/11:*

- **AC-001**: 重入费用计算
  - Given: entry_count=1（首次）
  - When: calculate_reentry_cost
  - Then: 返回 0

- **AC-002**: 通关奖励
  - Given: 中难度地图，玩家境界=地图境界
  - When: calculate_map_clear_rewards
  - Then: ling_shi=100, cultivation=80

- **AC-003**: 境界差额惩罚
  - Given: player_L=3, map_max_L=1
  - When: realm_gap_penalty
  - Then: 0.4（gap=2, 1.0-0.6=0.4）

- **AC-004**: 资源收集
  - Given: 活跃地图
  - When: collect_resource("ling_shi", 50)
  - Then: map_states[current_map].collected_ling_shi += 50

- **AC-005**: 资源转移
  - Given: collected_ling_shi=100
  - When: _flush_map_state
  - Then: GSM player.resources.ling_shi += 100

- **AC-006**: 三种结算路径
  - Given: 各 EndReason
  - When: end_exploration
  - Then: 按路径结算

- **AC-007**: 永久免费地图
  - Given: 永久免费地图
  - When: calculate_reentry_cost
  - Then: 始终 0

- **AC-008**: 事件节点防 SL
  - Given: generate_map 后事件节点
  - When: 检查 event_pool
  - Then: 含 pool 但不含具体事件模板

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/exploration_system/test_event_economy.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-1（generate_map）；Story 5-2（GSM exploration.* map_states）；Story 5-3（resolve_node）
- Unblocks: cultivation-system Epic（探索修为奖励写入 GSM player.*）；跨 Epic 经济闭环
