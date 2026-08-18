# Story 003: 战斗结束 serialize_field 快照导出 GSM.battle.deployment_snapshot

> **Epic**: deployment-system
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-18

## Completion Notes
**Completed**：2026-08-18
**Criteria**：11/11 通过（AC-001~011 由集成测试覆盖）
**Deviations**：
1. **JSON round-trip String key 防御（C-1 修复）**：`serialize_field()` 返回 int-key 快照 `{0: {...}, ...}`，Godot 4 JSON 序列化会把 int key 转 String，读回后 `deserialize_field()` 若仅匹配 int key 会静默丢阵位。实现 `deserialize_field` 键归一（`data.has(slot)` 或 `data.has(str(slot))` 均接受），并补 JSON round-trip 回归测试锁定该行为。
2. **移除死守卫（C-3）**：`load_unavailable_from_gsm(data: Dictionary)` 内 `if not data is Dictionary: return` 为死代码（参数类型标注已保证非 null 入参为 Dictionary，null 在参数绑定阶段抛错）——移除该行。
**Test Evidence**：`tests/integration/deployment_system/test_serialize_snapshot.gd`（20 测试全通过）；全量套件 70 scripts / 1289 tests / 1288 passing / 1 pending / 0 failing 零回归
**Code Review**：lead-programmer CONCERNS→已采纳（C-1 int-key JSON round-trip 静默丢数据 → deserialize 键归一 + JSON round-trip 回归测试；C-3 死守卫移除；C-4 测试清理直写属性加注释标注）；qa-lead GAPS→已补齐（G1 _get_gsm 返回 null 双守卫路径 + G2 deserialize 缺字段默认值填充 + G3 _state_from_string 非法字符串回退 EMPTY）

## Context

**GDD**: `design/gdd/deployment-system.md`
**Requirement**: `TR-deploy-003`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0016（上场阵位系统——Feature 层 Autoload + 内部状态机 + GSM 快照持久化）
**ADR Decision Summary**: 战斗期间阵位数据由 DeploymentSystem 内部 `_field` Dictionary 管理——不经过 GSM。战斗结束时 `serialize_field()` 导出阵位快照至 `GSM.battle.deployment_snapshot`，不可用角色列表通过 `sync_unavailable_to_gsm()` 同步至 GSM 用于存档持久化。这是 ADR-0011（StatusEffectSystem）/ ADR-0013（BindingManager）GSM 例外先例模式的第三处应用。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 不依赖 4.4+ 新特性。Dictionary 序列化为 Array[Dictionary]（RefCounted 实例不可直接序列化——同 StatusEffectSystem snapshot 模式）。`serialize_field()` <0.05ms。

**Control Manifest Rules (Feature 层)**:
- **Required**: 跨战斗角色死亡——`_unavailable_characters` 通过 GSM 持久化——需复活恢复（来源 ADR-0016）
- **Required**: GSM 例外——战斗期间阵位数据内部管理，仅战斗结束导出快照至 `battle.deployment_snapshot`（来源 ADR-0016）
- **Forbidden**: 绝不直接写 GSM 属性——始终通过第二层原子方法（来源 ADR-0001）
- **Forbidden**: 绝不将阵位数据（`_field`）实时写入 GSM——仅在战斗结束导出（来源 ADR-0016）

---

## Acceptance Criteria

*From ADR-0016 §验证标准 + §GSM 边界 + GDD deployment-system.md §验收标准:*

- [x] **AC-001**: `serialize_field()` 返回 Dictionary，含所有 6 个阵位的序列化数据（每 slot 含 character_id/is_front/state/deploy_turn）
- [x] **AC-002**: `serialize_field()` 输出为纯 Dictionary 序列化结构——不含 RefCounted/Node 引用（可直接 JSON 序列化）
- [x] **AC-003**: 战斗结束时调用 `GSM._set_battle_deployment_snapshot(snapshot)` 写入 `battle.deployment_snapshot`
- [x] **AC-004**: GSM 不可用时写入不崩溃（`is_instance_valid` + `has_method` 双守卫）
- [x] **AC-005**: `deserialize_field(data)` 从快照恢复阵位——恢复后 `get_field()` 与原快照一致
- [x] **AC-006**: `deserialize_field(data)` 对空/无效 data 安全处理——不崩溃
- [x] **AC-007**: `sync_unavailable_to_gsm()` 将 `_unavailable_characters` 同步至 GSM（战斗结束存档持久化入口）
- [x] **AC-008**: `load_unavailable_from_gsm(data)` 从 GSM 恢复 `_unavailable_characters`（读档时）
- [x] **AC-009**: snapshot round-trip——serialize_field 后 deserialize_field，阵位分布 + 状态字段一致
- [x] **AC-010**: GSM 写委托走第二层原子方法——不直接写 `GSM.battle.deployment_snapshot` 属性
- [x] **AC-011**: 不可用角色序列化——`_unavailable_characters` 每个 entry 含 {death_turn, death_battle_id, revival_methods}

---

## Implementation Notes

*Derived from ADR-0016 §决策 §关键接口 §GSM 边界:*

1. **文件位置**: `src/feature/deployment_system.gd`（同 story-001/002 文件——增量扩展）；GSM 第二层方法在 `src/foundation/game_state_manager.gd`
2. **serialize_field 实现**: 遍历 6 个 slot → 序列化为纯 Dictionary（character_id/is_front/state/deploy_turn 均为原始类型）。state 用 FieldState 枚举的 int 值（或 String 名）序列化
3. **写 GSM 委托**: `if is_instance_valid(GSM) and GSM.has_method("_set_battle_deployment_snapshot"): GSM._set_battle_deployment_snapshot(serialize_field())`
4. **GSM 第二层方法**: 在 `game_state_manager.gd` 新增 `_set_battle_deployment_snapshot(snapshot: Dictionary) -> void`——走 `_buffer_change("battle.deployment_snapshot", ...)` 管线（ADR-0001 批量信号发射）
5. **deserialize_field 实现**: 遍历快照 data → 重建 `_field` Dictionary（state 反序列化为 FieldState 枚举）
6. **sync_unavailable_to_gsm 实现**: `if is_instance_valid(GSM) and GSM.has_method("_set_player_unavailable_characters"): GSM._set_player_unavailable_characters(_unavailable_characters)`——或等价 GSM 第二层方法
7. **load_unavailable_from_gsm 实现**: 从传入 data 重建 `_unavailable_characters: Dictionary[int, Dictionary]`
8. **_unavailable_characters 结构**: key=character_id，value={death_turn: int, death_battle_id: str, revival_methods: Array}
9. **GSM 边界（ADR-0011/0013 先例）**: 战斗期间不写 GSM——`serialize_field`/`sync_unavailable_to_gsm` 仅在战斗结束（battle_end）时由 CombatSystem 调用
10. **state 序列化**: 建议用 FieldState 枚举名 String 序列化（可读性 + 前向兼容），deserialize 时用 `FieldState[state_name]` 反向映射
11. **测试模式**: `DS_SCRIPT.new()` + `var ds: Node` 动态分派 + 显式类型注解。GSM 依赖注入——测试用 mock/stub 或真实 GSM 第二层方法验证

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: `setup_field` 阵位初始化 + FieldState 枚举——已实现
- **Story 002**: `deploy()` / `remove_character()` / `is_targetable()`——已实现（本 story 依赖其阵位变更结果）
- **Story 004**: `mark_unavailable()` / `revive_character()` / `is_game_over()`——不可用角色的运行时标记逻辑（本 story 仅负责已标记数据的 GSM 同步）
- **CombatSystem battle_end 编排**: 调用 `serialize_field()` + `sync_unavailable_to_gsm()` 的时机——战斗 Epic（ADR-0008）职责
- **存档/读档集成**: snapshot 写入存档文件——存档 Epic（ADR-0002）职责（本 story 仅导出到 GSM battle 域）
- **BindingManager 战斗结束清理**: 绑定卡洗回与阵位清理的时序——战斗 Epic 职责

---

## QA Test Cases

*From ADR-0016 §验证标准 + GDD deployment-system.md §边界情况:*

- **AC-001**: serialize_field 返回完整结构
  - Given: 已 setup_field 4 人（含空位）
  - When: `ds.serialize_field()`
  - Then: 返回 Dictionary 含 6 个 slot 条目，每个含 character_id/is_front/state/deploy_turn
  - Edge cases: 空位也序列化（character_id=-1 + EMPTY）

- **AC-002**: serialize_field 纯序列化结构
  - Given: 阵位含角色
  - When: `ds.serialize_field()` → `JSON.stringify(result)`
  - Then: 无报错，可 JSON 序列化（无 RefCounted/Node 引用）
  - Edge cases: state 序列化为 int 或 String 原始类型

- **AC-003**: 战斗结束写 GSM
  - Given: GSM Autoload 可用，已 serialize_field
  - When: 战斗结束流程调用 `GSM._set_battle_deployment_snapshot(snapshot)`
  - Then: `GSM.battle.deployment_snapshot == snapshot`
  - Edge cases: 通过 `get_state("battle.deployment_snapshot")` 读取一致

- **AC-004**: GSM 不可用不崩溃
  - Given: 测试环境模拟 GSM 不可用
  - When: `ds.serialize_field()` 后写 GSM 委托
  - Then: 不崩溃，静默跳过
  - Edge cases: `is_instance_valid(GSM)` + `has_method` 双守卫

- **AC-005**: deserialize_field 恢复阵位
  - Given: 已 serialize_field 得到 data
  - When: 清空 `_field` → `ds.deserialize_field(data)` → `ds.get_field()`
  - Then: 恢复后的阵位与原快照一致
  - Edge cases: state 枚举正确反序列化（STANDBY/READY/ACTED/DEAD/EMPTY）

- **AC-006**: deserialize_field 空数据安全
  - Given: 传入空 Dictionary 或无效 data
  - When: `ds.deserialize_field({})`
  - Then: 不崩溃（安全返回或保持空阵位）
  - Edge cases: 缺字段的 entry 用默认值填充

- **AC-007**: sync_unavailable_to_gsm 同步
  - Given: `_unavailable_characters` 含 2 个角色
  - When: `ds.sync_unavailable_to_gsm()`
  - Then: GSM 收到不可用角色列表（用于存档持久化）
  - Edge cases: 空列表时同步空 Dictionary

- **AC-008**: load_unavailable_from_gsm 恢复
  - Given: GSM 存档数据含不可用角色
  - When: `ds.load_unavailable_from_gsm(data)`
  - Then: `_unavailable_characters` 重建
  - Edge cases: 读档后 `is_targetable`/`can_deploy` 尊重不可用状态

- **AC-009**: snapshot round-trip 一致性
  - Given: 已 setup_field 3 人 + 1 人 ACTED
  - When: `data = serialize_field()` → `deserialize_field(data)` → 对比 get_field()
  - Then: slot_index/character_id/is_front/state/deploy_turn 全一致
  - Edge cases: 状态枚举 round-trip 无损

- **AC-010**: GSM 写走第二层方法
  - Given: 写入 battle.deployment_snapshot
  - When: 检查写路径
  - Then: 通过 `_set_battle_deployment_snapshot` 第二层原子方法（不直接赋值属性）
  - Edge cases: 走 `_buffer_change` + 帧末 `batch_updated` 发射（ADR-0001）

- **AC-011**: 不可用角色 entry 结构
  - Given: 角色 101 标记不可用，death_context 含 death_turn/death_battle_id
  - When: 检查 `_unavailable_characters[101]`
  - Then: 含 {death_turn, death_battle_id, revival_methods}
  - Edge cases: revival_methods 为 Array（可为空）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/deployment_system/test_serialize_snapshot.gd` — must exist and pass
**Status**: [x] Created and passing (20 tests)

---

## Dependencies

- Depends on: Story 002（deploy/remove 完整阵位变更链路——serialize 需覆盖所有状态）；Story 001（FieldState 枚举 + `_field` 数据模型）
- Unlocks: Story 004（不可用角色完整生命周期需 sync/load GSM 链路）；战斗 Epic（battle_end 调用 serialize_field + sync_unavailable_to_gsm）；存档 Epic（snapshot 持久化）
