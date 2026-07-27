# Story 003: 第三层信号订阅层 + batch_updated 展平字典

> **Epic**: 游戏状态管理器
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-26

## 上下文

**GDD**: `design/gdd/game-state-manager.md`
**需求**: `TR-gsm-003`

**管辖 ADR**: ADR-0001: 游戏状态管理器 — Autoload 单例 + 三层 API
**ADR 决策摘要**: 写入优先、信号在后。13 个命名事件 + batch_updated 携带展平 `{path: {old, new}}` 字典。同帧去重（同一路径多次写入仅最后一次发射）。Cat 1 信号通过 `_emit_signal_safe()` 路由。

**引擎**: Godot 4.6 | **风险**: MEDIUM

**控制清单规则 (Foundation 层)**:
- 必需: `batch_updated` 信号携带展平的 `{path: {old, new}}` 字典——消费者通过路径前缀过滤（ADR-0001）
- 必需: Cat 2 信号必须通过 `_emit_signal_safe()` 包装器路由——信号链深度追踪（ADR-0007）
- 禁止: 绝不在 Cat 1 信号处理器内写回 GSM（ADR-0001, ADR-0007）
- 禁止: 绝不超出信号链深度 4——截断 + `push_error`（ADR-0007）
- 禁止: 绝不声明 SignalBus Autoload——信号属于其语义所有者（ADR-0007）
- 禁止: 绝不发射携带指令（"该做什么"）的信号——信号携带事实（"发生了什么"）（ADR-0007）

---

## 验收标准

*来自 GDD:*

- [ ] **AC-013**: GIVEN 系统修改 `player.realm`，WHEN 监听 `realm_changed` 信号，THEN 收到包含新旧境界的载荷
- [ ] **AC-014**: GIVEN 场上角色属性变更，WHEN 监听 `resource_changed` 以外的信号，THEN 不触发（信号不混淆）
- [ ] **AC-015**: GIVEN 同帧内多次修改 `player.cultivation`，WHEN 检查信号广播，THEN 仅最后一次变更广播事件
- [ ] **AC-016**: GIVEN 批量修改（战斗结算），WHEN 监听信号，THEN 收到一个 `batch_updated` 事件而非多个逐条事件

---

## 实现说明

*来自 ADR-0001 实现指南:*

### 13 个命名信号声明

```
signal gsm_initialized()
signal realm_changed(old_realm: int, new_realm: int)
signal cultivation_changed(delta: int, current: int, max_val: int)
signal cultivation_full(current: int, max_val: int)
signal resource_changed(type: StringName, delta: int, balance: int)
signal action_points_changed(delta: int, current: int, max_val: int)
signal deck_modified(card_id: int, action: StringName)
signal battle_started(enemy_id: StringName, seed: int)
signal battle_ended(result: StringName, rewards: Dictionary)
signal scene_changed(from_scene: StringName, to_scene: StringName)
signal card_collection_changed(card_id: int, action: StringName)
signal progression_reset(reason: StringName)
signal batch_updated(changes: Dictionary)
signal card_validation_ready()
```

### 信号发射机制

1. **写入优先，信号在后**：所有原子方法先执行数据写入（第二层），写入成功后才发射信号
2. **同帧去重**：使用 `Dictionary[String, Dictionary]` 作为帧内变更缓冲——`_pending_changes: Dictionary`
   - 键 = 完整路径（如 `"player.cultivation"`）
   - 值 = `{old: <写入前值>, new: <写入后值>}`
   - 同一路径多次写入 -> 覆盖 `new` 值 -> 仅最后一次 new 和首次 old 保留
   - 帧末通过 `call_deferred("_flush_pending_changes")` 一次性发射
3. **批量变更 vs 单路径变更判定**：
   - 如果 `_pending_changes` 中仅 1 条 -> 发射对应域信号（如 `cultivation_changed`）
   - 如果 >= 2 条 -> 发射 `batch_updated({path: {old, new}})` 展平字典
4. **递归写入检测**：在信号回调执行期间设置 `_emitting_in_progress = true`；若回调中再次调用原子写入方法 -> `push_warning("recursive write to {path} detected")` 但允许执行

### 展平字典格式

```
batch_updated.changes = {
  "player.resources.ling_shi": {old: 100, new: 150},
  "player.cultivation":       {old: 200, new: 650},
  "collection.owned_cards":   {old: [...], new: [...]}
}
```

消费者按前缀过滤自己关心的路径：
```
func _on_batch_updated(changes: Dictionary) -> void:
  for path_key in changes:
    if path_key.begins_with("player.resources"):
      _update_resource_display(changes[path_key].new)
```

### subscribe/unsubscribe 接口

```
subscribe(event_name: StringName, callback: Callable) → void
  # event_name 必须在有效信号名列表中
  # 无效时 push_error 并忽略

unsubscribe(event_name: StringName, callback: Callable) → void
  # 安全取消；未找到时不报错
```

---

## QA 测试用例

- **AC-013**: realm_changed 信号携带新旧境界
  - Given: `player.realm = 1`（炼气）；监听方已 `subscribe("realm_changed", callback)`
  - When: 通过 `change_realm(2)` 修改境界
  - Then: 回调收到 `{old_realm: 1, new_realm: 2}` 载荷
  - 边界情况: 新旧境界相同时不发射信号（无变更去重）

- **AC-014**: 信号不混淆
  - Given: 监听方 A 订阅 `resource_changed`，监听方 B 订阅 `cultivation_changed`
  - When: `add_cultivation(100)` 触发修为变更
  - Then: 监听方 A 不收到信号；监听方 B 收到 `cultivation_changed`
  - 边界情况: 一次操作影响多个域 -> 所有相关信号均正确发射

- **AC-015**: 同帧去重
  - Given: 监听方订阅 `cultivation_changed`
  - When: 同帧内调用 3 次 `add_cultivation(10)` -> `add_cultivation(20)` -> `add_cultivation(30)`
  - Then: 帧末仅发射 1 次信号，载荷中 `delta = 60`（总和）、`current = 最终值`
  - 边界情况: 混合相同路径和不同路径的写入 -> 不同路径各自去重

- **AC-016**: batch_updated 批量事件
  - Given: 监听方订阅 `batch_updated`
  - When: 战斗结算执行 `add_resource(灵石, 100)` + `add_cultivation(200)` + 添加卡牌（3 次跨域写入）
  - Then: 帧末发射 1 个 `batch_updated` 信号，changes 字典包含 3 条 `{path: {old, new}}` 条目
  - 边界情况: changes 字典为空 -> 不发射 signal

---

## 测试证据

**Story 类型**: Logic
**需要证据**: `tests/unit/gsm/signal_layer_and_batch_updated_test.gd` — 必须存在且通过
**状态**: [ ] 尚未创建

---

## 依赖

- 依赖: Story 002（原子写入方法——信号在写入后发射）
- 解锁: Story 005（校验跳过模式——依赖信号层就绪）