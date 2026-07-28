# Story 002: 第二层原子写入方法

> **Epic**: 游戏状态管理器
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-26
> **Last Updated**: 2026-07-28

## 上下文

**GDD**: `design/gdd/game-state-manager.md`
**需求**: `TR-gsm-002`

**管辖 ADR**: ADR-0001: 游戏状态管理器 — Autoload 单例 + 三层 API
**ADR 决策摘要**: 所有写入必须通过第二层专用原子方法，绝不直接修改属性。原子方法内执行类型校验、范围校验、路径校验，写入成功后发射对应信号。

**引擎**: Godot 4.6 | **风险**: MEDIUM

**控制清单规则 (Foundation 层)**:
- 必需: 所有游戏状态写入必须通过 GSM 第二层原子方法（ADR-0001）
- 禁止: 绝不直接写 GSM 属性——始终通过第二层原子方法（ADR-0001）
- 禁止: 绝不使用通用 `set(path, value)`——使用专用原子方法（ADR-0001）
- 禁止: 绝不在 `_process()` 热路径中写 GSM——写入仅在事件响应中（ADR-0001）
- 护栏: GSM 读取 <0.1ms/帧（35 个消费者 x O(1)）；信号发射 <0.5ms/战斗结算（ADR-0001）

---

## 验收标准

*来自 GDD:*

- [x] **AC-003**: GIVEN 系统A调用 `add_cultivation(100)`，WHEN 系统B读取 `player.cultivation`，THEN 值增加了100
- [x] **AC-004**: GIVEN 修为值500，WHEN 调用 `spend_resource("ling_shi", 30)` 且灵石余额>=30，THEN 灵石扣除30，返回true
- [x] **AC-005**: GIVEN 灵石余额20，WHEN 调用 `spend_resource("ling_shi", 30)`，THEN 灵石不扣除，返回false
- [x] **AC-006**: GIVEN 写入 `set("nonexistent.path", value)`，WHEN 调用，THEN 拒绝写入，日志记录错误
- [x] **AC-007**: GIVEN 战斗开始，WHEN 调用 `battle_start()`，THEN `battle` 域初始化，发射 `battle_started` 事件
- [x] **AC-008**: GIVEN 战斗结束，WHEN 调用 `battle_end(victory)`，THEN `battle` 域清空为null
- [x] **AC-009**: GIVEN 修为溢出，WHEN 修为达到 max_cultivation 后继续增加，THEN 溢出部分存储在溢出字段
- [x] **AC-010**: GIVEN 突破后，WHEN 读取修为值，THEN 溢出修为计入新境界进度
- [x] **AC-011**: GIVEN 角色死亡，WHEN 执行轮回结算，THEN `player.cultivation` 清零，`collection.owned_cards` 保留，`progression` 更新
- [x] **AC-012**: GIVEN 新游戏开始，WHEN 身份选择完成，THEN `player.identity_id` 正确设置

---

## 实现说明

*来自 ADR-0001 实现指南:*

### 核心原子方法（本 Story 实现范围）

```
# 修为（仅 CultivationSystem 调用）
add_cultivation(amount: int, source: String = "") → void
  # player.cultivation += amount；溢出部分 -> overflow_pool
  # 溢出时 player.cultivation_full = true
  # 发射 batch_updated({"player.cultivation": {old, new}, "player.cultivation_full": ...})

# 资源（仅 ResourceSystem 调用）
spend_resource(type: StringName, amount: int) → bool
  # 余额不足返回 false；成功 -> 发射 batch_updated({"player.resources.{type}": {old, new}})

add_resource(type: StringName, amount: int) → bool
  # type 不存在返回 false；成功 -> 发射 resource_changed

# 战斗生命周期（仅 CombatSystem 调用）
battle_start(config: Dictionary) → void
  # 重复调用保护：battle != null 时 push_warning + return
  # 深度复制 player/collection 数据 -> battle 域
  # battle.snapshot_realm = player.realm（锁定境界快照）
  # 发射 battle_started

battle_end(result: Dictionary) → void
  # battle == null 时 push_warning + return
  # 结算后将 battle = null（GC 可回收）
  # 发射 battle_ended

# 身份
set_identity(identity_id: StringName) → void
  # player.identity_id = identity_id

# 死亡/轮回结算
reincarnation_reset() → void
  # player.cultivation = 0，player.realm 重置默认
  # player.resources 重置默认
  # collection.owned_cards 保留
```

### 内部校验引擎（所有原子方法调用）
- `_validate_path(path: String) → bool`：路径必须存在于数据树中；不存在 -> 错误日志 + 返回 false
- `_validate_type(path: String, value: Variant) → bool`：写入值类型与字段默认值类型一致
- `_validate_range(path: String, value: Variant) → bool`：资源>=0，修为<=max，境界在枚举内
- `_write_and_emit(path: String, old_val, new_val)`：执行写入 -> 记录变更 -> 待信号发射（同帧去重）

### 重要设计约束
- "guard" 一词用于语义屏障，非多线程锁（GDScript 单线程）
- 校验失败时 `push_error()` 并拒绝写入；调用方应主动检查返回值（如 `spend_resource()` 返回 bool）
- `set(path, value)` 通用写入仅内部使用、供 Story 003 信号层调用，外部消费者必须使用专用方法

---

## QA 测试用例

- **AC-003**: 修为增加跨系统可见
  - Given: `player.cultivation = 500`
  - When: 系统 A 调用 `GSM.add_cultivation(100)`
  - Then: 系统 B 读取 `GSM.player.cultivation` 返回 600
  - 边界情况: 增加后超过 max_cultivation -> 溢出部分入 overflow_pool

- **AC-004**: 资源消费成功
  - Given: `player.resources["ling_shi"] = 100`
  - When: `GSM.spend_resource("ling_shi", 30)`
  - Then: 返回 true；`player.resources["ling_shi"]` 变为 70
  - 边界情况: 恰好余额=消费额时返回true

- **AC-005**: 资源消费因余额不足失败
  - Given: `player.resources["ling_shi"] = 20`
  - When: `GSM.spend_resource("ling_shi", 30)`
  - Then: 返回 false；`player.resources["ling_shi"]` 仍为 20

- **AC-006**: 写入不存在路径被拒绝
  - Given: 数据树中不存在 `nonexistent.path`
  - When: `GSM.set("nonexistent.path", 42)`
  - Then: `push_error()` 日志；写入不执行
  - 边界情况: 路径存在但类型不匹配 -> 同样拒绝

- **AC-007**: battle_start 初始化战斗域
  - Given: 游戏在探索中，`battle == null`
  - When: `GSM.battle_start({enemy_id: "boss_01", seed: 12345})`
  - Then: `battle != null`；信号 `battle_started` 发射
  - 边界情况: 重复调用 `battle_start()` -> `push_warning()` + return（幂等保护）

- **AC-008**: battle_end 清理战斗域
  - Given: 战斗进行中，`battle != null`
  - When: `GSM.battle_end({result: "victory", rewards: {...}})`
  - Then: `battle == null`；信号 `battle_ended` 发射
  - 边界情况: 无战斗时调用 `battle_end()` -> `push_warning()` + return

- **AC-009**: 修为溢出存储
  - Given: `player.cultivation = 950`，`max_cultivation = 1000`
  - When: `GSM.add_cultivation(100)`
  - Then: `player.cultivation = 1000`，`player.overflow_pool = 50`
  - 边界情况: 溢出后再次 `add_cultivation` -> 继续追加到 overflow_pool

- **AC-010**: 突破后溢出修为转入
  - Given: `player.overflow_pool = 200`，执行突破后新 `max_cultivation = 1500`
  - When: 读取 `player.cultivation`
  - Then: 200 计入新境界进度（当前 cultivation = 200）
  - 边界情况: 溢出量超过新 max -> 再次溢出到 overflow_pool

- **AC-011**: 角色死亡轮回结算
  - Given: `player.cultivation = 800`，`collection.owned_cards = ["card_001", "card_002"]`
  - When: `GSM.reincarnation_reset()`
  - Then: `player.cultivation = 0`，`player.realm` 重置默认，`collection.owned_cards` 保持，`progression` 更新
  - 边界情况: 重复调用 -> 幂等安全

- **AC-012**: 身份选择正确设置
  - Given: 身份选择系统通过 `GSM.set_identity("identity_03")`
  - When: 读取 `GSM.player.identity_id`
  - Then: 返回 `"identity_03"`
  - 边界情况: 空字符串或无效 ID -> 拒绝

---

## 测试证据

**Story 类型**: Logic
**需要证据**: `tests/unit/gsm/atomic_write_methods_test.gd` — 必须存在且通过
**状态**: [x] 已创建——32/32 测试全部通过

---

## 依赖

- 依赖: Story 001（Autoload 基础结构）
- 解锁: Story 003（信号订阅层）、Story 004（序列化）