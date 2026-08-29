# Story 002: GSM player.* 数据存储 + batch_updated 传播

> **Epic**: cultivation-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-29

## Context

**GDD**: `design/gdd/cultivation-system.md`
**Requirement**: `TR-cult-002`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: 待定（CultivationSystem ADR 尚未编写——本 Story 遵循 GDD §5 + GSM 现有 player.* 域 + batch_updated 管线）
**ADR Decision Summary**: CultivationSystem 通过 GSM 第二层原子方法写入 player.cultivation / overflow_pool / cultivation_full——所有写入通过 _buffer_change 进入帧末 batch_updated 管线。CultivationSystem 不绕过 GSM 直接赋值。

**Engine**: Godot 4.6 | **Risk**: LOW（GSM batch_updated 管线已实现，本 Story 是集成验证层）
**Engine Notes**: GSM _buffer_change → _schedule_flush → call_deferred(_do_flush) → _flush_pending_changes → batch_updated.emit。均为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: 修为值与溢出池由 GSM player.* 域管理 —— 来源: GDD §5
- **Required**: 写入通过 GSM 第二层原子方法 —— 来源: ADR-0001
- **Forbidden**: 绕过 GSM 直接修改 player.* 域字段 —— 来源: ADR-0001

---

## Acceptance Criteria

*From GDD §5 修为获取流程 + GSM batch_updated 管线:*

- [ ] **AC-001**: CultivationSystem.gain_cultivation 写入通过 GSM add_cultivation → _buffer_change → batch_updated 帧末传播
- [ ] **AC-002**: player.cultivation 路径出现在 batch_updated 载荷中
- [ ] **AC-003**: player.cultivation_full 路径在修为满值时出现在 batch_updated 中
- [ ] **AC-004**: player.overflow_pool 路径在溢出时出现在 batch_updated 中
- [ ] **AC-005**: GSM.serialize() 包含 player.* 域完整修为数据（cultivation / max_cultivation / cultivation_full / overflow_pool）
- [ ] **AC-006**: deserialize() 往返后修为数据完整等价
- [ ] **AC-007**: CultivationSystem 不绕过 GSM 直接修改 player.*（验证无直接赋值代码路径）

---

## Implementation Notes

*Derived from GDD §5 + GSM batch_updated 管线:*

1. **文件位置**: `src/feature/cultivation_system.gd` — 无需新增方法（Story 5-6 已实现 gain_cultivation）
2. **集成验证 Story**: GSM 已有完整的 player.* 域 + batch_updated 管线 + serialize/deserialize
3. **本 Story 重点是测试验证** — 验证 CultivationSystem → GSM → batch_updated → serialize 完整链路
4. **不绕过 GSM 验证**: 检查 cultivation_system.gd 源码——所有 player.* 访问通过 gsm.add_cultivation / gsm.player.* 读取
5. **batch_updated 载荷路径**: cultivation / cultivation_full / overflow_pool / max_cultivation

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: settle_overflow + 突破后溢出结算——本 Story 只验证数据存储传播
- **Story 004**: realm_upgraded 信号订阅 + check_breakthrough——本 Story 不处理突破
- **UI**: 修为条 UI 渲染——UI Epic 职责

---

## QA Test Cases

*From GDD §5 + GSM batch_updated 管线:*

- **AC-001**: batch_updated 传播
  - Given: 订阅 batch_updated
  - When: gain_cultivation(50, "combat") + await 帧末
  - Then: batch_updated 信号发射

- **AC-002**: player.cultivation 路径
  - Given: 同上
  - When: 检查 batch_updated 载荷
  - Then: 含 "player.cultivation" 路径

- **AC-003**: player.cultivation_full 路径
  - Given: 修为接近满值
  - When: gain_cultivation 触发满值
  - Then: batch_updated 含 "player.cultivation_full" 路径

- **AC-004**: player.overflow_pool 路径
  - Given: 修为已满
  - When: gain_cultivation 触发溢出
  - Then: batch_updated 含 "player.overflow_pool" 路径

- **AC-005**: serialize 包含 player.*
  - Given: 修为有数据
  - When: serialize()
  - Then: 含 player.cultivation / max_cultivation / cultivation_full / overflow_pool

- **AC-006**: deserialize 往返
  - Given: serialize 后
  - When: deserialize
  - Then: 修为数据完整等价

- **AC-007**: 不绕过 GSM
  - Given: CultivationSystem 源码
  - When: 检查 player.* 写入路径
  - Then: 所有写入通过 gsm.add_cultivation / gsm 第二层方法

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/cultivation_system/test_gsm_storage_batch_update.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-6（gain_cultivation）；GSM add_cultivation + batch_updated 管线（已实现）
- Unblocks: Story 003（溢出结算需要数据存储传播验证）；Story 004（突破检查需要 player.* 数据）
