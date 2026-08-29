# Story 003: settle_overflow + 突破后溢出结算

> **Epic**: cultivation-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-29

## Context

**GDD**: `design/gdd/cultivation-system.md`
**Requirement**: `TR-cult-003`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: 待定（CultivationSystem ADR 尚未编写——本 Story 遵循 GDD §6-7 + §公式 2）
**ADR Decision Summary**: 突破成功后 overflow_pool 立即触发溢出结算：pill_count = floor(overflow_pool / PILL_CONVERSION_UNIT)，发放 pill_count 个属性丹，剩余 overflow_pool = overflow_pool mod PILL_CONVERSION_UNIT。未转化部分保留到下次突破。

**Engine**: Godot 4.6 | **Risk**: LOW（纯整数运算 + GSM 第二层写入）
**Engine Notes**: floor/mod 运算为 GDScript 内置操作符。GSM _set_resource_ling_shi / add_cultivation 用于资源写入。均为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: 突破后 overflow_pool 立即结算 —— 来源: GDD §7
- **Required**: 未转化溢出保留到下次突破 —— 来源: GDD §6 边界情况
- **Forbidden**: overflow_pool 归零（除非恰好整除）—— 来源: GDD §6 边界情况

---

## Acceptance Criteria

*From GDD §6-7 突破后修为处理 + §公式 2 溢出→属性丹结算:*

- [ ] **AC-001**: `settle_overflow()` 方法——计算 pill_count = floor(overflow_pool / 100)，发放属性丹
- [ ] **AC-002**: 结算后 overflow_pool 保留余数（overflow_pool mod 100）
- [ ] **AC-003**: 返回 {pill_count, remaining_overflow} Dictionary
- [ ] **AC-004**: overflow_pool = 0 时返回 pill_count=0，不报错
- [ ] **AC-005**: overflow_pool < 100 时 pill_count=0，remaining 保留原值
- [ ] **AC-006**: `update_max_cultivation(new_realm)` 更新 max_cultivation 后触发 settle_overflow
- [ ] **AC-007**: 结算后 batch_updated 传播 overflow_pool 变更

---

## Implementation Notes

*Derived from GDD §6-7 + §公式 2:*

1. **文件位置**: `src/feature/cultivation_system.gd` — 新增 settle_overflow + update_max_cultivation
2. **PILL_CONVERSION_UNIT**: 常量 100（每 100 溢出修为 = 1 属性丹）
3. **settle_overflow()**:
   - 读取 GSM player.overflow_pool
   - pill_count = floor(overflow_pool / 100)
   - remaining = overflow_pool % 100
   - 更新 GSM player.overflow_pool = remaining（通过 GSM 原子方法）
   - 返回 {pill_count, remaining_overflow}
4. **update_max_cultivation(new_realm)**:
   - 计算 max_cultivation = BASE_MAX × 1.5^(new_realm - 1)
   - 更新 GSM player.max_cultivation
   - 调用 settle_overflow()
5. **属性丹发放**: 本 Story 只计算数量，不实现实际丹药发放（炼丹系统职责）——返回 pill_count 供调用方处理
6. **GSM 写入**: overflow_pool 更新通过 GSM._buffer_change 路径（需新增 GSM 第二层方法或直接用现有路径）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 004**: realm_upgraded 信号订阅 + check_breakthrough——本 Story 不处理突破触发
- **属性丹实际发放**: 炼丹系统职责——本 Story 只返回 pill_count
- **突破失败修为损失 10%**: 渡劫系统职责

---

## QA Test Cases

*From GDD §6-7 + §公式 2:*

- **AC-001**: settle_overflow 计算
  - Given: overflow_pool = 450
  - When: settle_overflow()
  - Then: pill_count = 4

- **AC-002**: 保留余数
  - Given: overflow_pool = 450
  - When: settle_overflow()
  - Then: remaining_overflow = 50

- **AC-003**: 返回结构
  - Given: 任意 overflow_pool
  - When: settle_overflow()
  - Then: 返回 {pill_count, remaining_overflow}

- **AC-004**: overflow_pool = 0
  - Given: overflow_pool = 0
  - When: settle_overflow()
  - Then: pill_count = 0, remaining = 0

- **AC-005**: overflow_pool < 100
  - Given: overflow_pool = 50
  - When: settle_overflow()
  - Then: pill_count = 0, remaining = 50

- **AC-006**: update_max_cultivation
  - Given: realm = 2 (筑基)
  - When: update_max_cultivation(2)
  - Then: max_cultivation = 1500, settle_overflow 被触发

- **AC-007**: batch_updated 传播
  - Given: 订阅 batch_updated
  - When: settle_overflow() + await 帧末
  - Then: batch_updated 含 player.overflow_pool 路径

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/cultivation_system/test_settle_overflow.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-6（gain_cultivation）；GSM player.overflow_pool（已实现）
- Unblocks: Story 004（突破检查需要 update_max_cultivation）；tribulation-system Epic（渡劫成功后调用 settle_overflow）
