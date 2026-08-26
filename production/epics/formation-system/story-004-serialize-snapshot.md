# Story 004: serialize_all 快照导出 GSM.battle.formation_snapshot

> **Epic**: 阵法系统 (Formation System)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/formation-system.md`
**Requirement**: `TR-formation-001`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0024（阵法系统 — Feature 层 Autoload + 内部条件状态机 + GSM 快照持久化）
**ADR Decision Summary**: 战斗期间阵法数据和角色归属由 FormationSystem 内部管理，战斗结束时 `serialize_all()` 导出阵位快照至 `GSM.battle.formation_snapshot` 用于存档持久化；`clear_all_formations()` 清理所有阵法和归属数据。

**Engine**: Godot 4.6 | **Risk**: LOW（Dictionary 序列化 + GSM 写入均为 4.x 成熟 API）
**Engine Notes**: 不依赖 4.4+ 新增 API。`Dictionary` 序列化、GSM 第二层写入为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: 战斗期间阵法数据内部管理，战斗结束导出快照至 GSM（ADR-0024 —— ADR-0011/0013/0016 先例模式）
- **Forbidden**: 绝不直接写 GSM 属性——始终通过第二层原子方法（ADR-0001）
- **Forbidden**: 绝不在 `_process()` 热路径中写 GSM——写入仅在事件响应中（ADR-0001）

---

## Acceptance Criteria

*From GDD `design/gdd/formation-system.md` §5 角色归属 + ADR-0024 §GSM 边界 §验证标准，scoped to this story:*

- [x] **AC-001**: 战斗结束时 `serialize_all()` 返回完整阵位快照（`_slots` + `_affiliations` + `_next_formation_id`）
- [x] **AC-002**: 快照导出至 `GSM.battle.formation_snapshot`（通过 GSM 第二层原子方法写入）
- [x] **AC-003**: `deserialize_all(data)` 从快照恢复阵位状态 + 归属关系（读档/战斗快照恢复）
- [x] **AC-004**: `deserialize_all()` 中逐条验证 character_id——失效则跳过该归属 + WARN 日志（不阻塞阵法自身状态恢复）
- [x] **AC-005**: `clear_all_formations()` 清空所有阵法位（→EMPTY）+ 清除所有归属；`_next_formation_id` 保留（不重置）

---

## Implementation Notes

*Derived from ADR-0024 §关键接口 §GSM 边界 §Autoload 初始化 §风险:*

1. **文件位置**: `src/feature/formation_system.gd`（扩展 Story 001/002/003——新增 `serialize_all()` / `deserialize_all()` / `clear_all_formations()`）
2. **`serialize_all() → Dictionary`**（ADR-0024 §关键接口）:
   - 返回 `{slots: Dictionary, affiliations: Dictionary, next_formation_id: int}`
   - `slots` 为 `_slots` 快照（3 阵位 × 10 字段 ≈ 300 bytes）
   - `affiliations` 为 `_affiliations` 快照（最多 6 角色 × 8 bytes ≈ 48 bytes）
3. **快照导出至 GSM**（ADR-0024 §GSM 边界——ADR-0011/0013/0016 先例模式）:
   - 战斗结束调用点（CombatSystem.battle_end）→ `serialize_all()` → 通过 GSM 第二层原子方法写入 `GSM.battle.formation_snapshot`
   - 绝不直接写 GSM 属性（控制清单 Forbidden——ADR-0001）
   - 写入仅在事件响应中（战斗结束事件），不在 `_process()` 热路径
4. **`deserialize_all(data: Dictionary) → void`**（ADR-0024 §关键接口 §风险——归属悬空）:
   - 从快照恢复 `_slots` + `_affiliations` + `_next_formation_id`
   - 逐条验证 `affiliations` 中的 character_id——验证失败（角色已不可用，如全部阵亡）→ 跳过该归属 + WARN 日志
   - 归属关系悬空不影响阵法自身状态恢复
5. **`clear_all_formations() → void`**（ADR-0024 §关键接口）:
   - 所有阵位 → EMPTY
   - 所有归属 → 清除
   - `_next_formation_id` 保留（不重置，避免 ID 冲突）
   - 由 `CombatSystem.battle_end()` 调用
6. **GSM 只读边界**（ADR-0024 §GSM 边界）:
   - FormationSystem 不调用 GSM 写入方法管理内部状态——所有阵法数据内部管理
   - 仅战斗结束时通过 GSM 第二层方法导出快照
7. **序列化格式注意**（ADR-0002 存档规范）:
   - 快照 Dictionary 中所有字段为 JSON 可序列化类型（int / String / Array / Dictionary）——不含 RefCounted 引用或 Resource 引用
   - `template_id` 为 StringName 需转为 String 序列化（读档时转回）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: 阵法位数据模型与状态机——本 story 只序列化/反序列化已有数据结构
- **Story 002**: 激活条件重判——本 story 不触发重判逻辑
- **Story 003**: 光环效果计算——光环值是动态计算，不序列化
- **CombatSystem Epic**: `battle_end()` 调用 `clear_all_formations()` 的具体编排时机
- **SaveLoad Epic**: 存档文件的 JSON 序列化与迁移链——本 story 只导出内存快照 Dictionary

---

## QA Test Cases

*Derived from ADR-0024 §验证标准 §风险:*

- **AC-001**: serialize_all 返回完整快照
  - Given: 阵法区有 2 个阵法（1 ACTIVE + 1 UNACTIVE）；2 个角色归属 ACTIVE 阵法
  - When: `serialize_all()`
  - Then: 返回 Dictionary 含 `slots`（2 个非 EMPTY 阵位）、`affiliations`（2 条归属）、`next_formation_id`
  - Edge cases: 空阵法区时 slots 为 3 个 EMPTY 阵位

- **AC-002**: 快照写入 GSM.battle.formation_snapshot
  - Given: `serialize_all()` 已调用；GSM 已初始化
  - When: 通过 GSM 第二层原子方法写入快照
  - Then: `GSM.battle.formation_snapshot` 可读取到完整快照
  - Edge cases: 绝不直接写 GSM 属性（走第二层原子方法）

- **AC-003**: serialize/deserialize 往返完整性
  - Given: 阵法区 2 阵法 + 2 归属关系
  - When: `var data = serialize_all()` → `deserialize_all(data)`
  - Then: `_slots` 阵位状态与归属关系完整恢复
  - Edge cases: 往返后 `get_slot_states()` / `get_character_affilation()` 与原状态一致

- **AC-004**: deserialize 归属悬空跳过
  - Given: 快照含 character_id=999 的归属；该角色已不可用
  - When: `deserialize_all(data)`
  - Then: 该归属被跳过 + WARN 日志；阵法自身状态正常恢复
  - Edge cases: 悬空归属不影响其他角色归属与阵位状态

- **AC-005**: clear_all_formations 清理
  - Given: 阵法区有阵法 + 归属关系
  - When: `clear_all_formations()`
  - Then: 所有阵位 → EMPTY；`_affiliations` 清空；`_next_formation_id` 保留（值不变）
  - Edge cases: 战斗结束后可开始新战斗，ID 不冲突

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/formation_system/test_serialize_snapshot.gd` — must exist and pass
**Status**: [x] Created — 13 tests passing (test_serialize_snapshot.gd)

---

## Dependencies

- Depends on: Story 003（serialize_all 需在阵位数据 + 归属管理 + 状态机稳定后导出）；跨 Epic 依赖 GSM（ADR-0001）第二层写入方法 + CombatSystem battle_end 集成点
- Unlocks: None（阵法 Epic 末位 story）
