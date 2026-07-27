# Story 004: 序列化与反序列化

> **Epic**: 游戏状态管理器
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-26

## 上下文

**GDD**: `design/gdd/game-state-manager.md`
**需求**: `TR-gsm-002`

**管辖 ADR**: ADR-0001: 游戏状态管理器 — Autoload 单例 + 三层 API
**ADR 决策摘要**: `serialize() → Dictionary` 排除 `battle` 和 `session` 域。`deserialize(data: Dictionary) → bool` 校验后返回成功/失败，失败时内存状态不变。存档 I/O 由 SaveLoadSystem 负责——GSM 仅提供数据。

**引擎**: Godot 4.6 | **风险**: MEDIUM

**控制清单规则 (Foundation 层)**:
- 必需: 存档格式必须为 JSON，以 `schema_version`（递增整数）为唯一迁移驱动字段（ADR-0002）
- 必需: 原子写入策略：`.tmp` 文件 -> `DirAccess.rename_absolute()` -> `.bak` 备份 -> 删除 `.bak`（ADR-0002）
- 禁止: 绝不使用 `JSON.parse_string()` 读取存档——使用 `JSON.new().parse()` 并检查 Error 返回值（ADR-0002）
- 护栏: GSM 读取 <0.1ms/帧（ADR-0001）

---

## 验收标准

*来自 GDD:*

- [ ] **AC-017**: GIVEN 战斗中存档，WHEN 序列化状态，THEN `battle` 域和 `session` 域不包含在输出中
- [ ] **AC-018**: GIVEN 读档文件损坏，WHEN 调用 `deserialize(corrupted_data)`，THEN 返回false，内存状态不变
- [ ] **AC-019**: GIVEN 旧版本存档缺少新字段，WHEN 调用 `deserialize(old_data)`，THEN 缺失字段采用默认值，返回true

---

## 实现说明

*来自 ADR-0001 实现指南:*

### serialize() → Dictionary

```
func serialize() → Dictionary:
  var data := {}
  for domain in ALL_DOMAINS:
    if domain in NON_PERSISTABLE_DOMAINS:  # ["battle", "session"]
      continue
    data[domain] = _deep_copy(_state[domain])
  return data
```

- `ALL_DOMAINS = ["meta", "player", "collection", "deck", "battle", "exploration", "narrative", "progression", "session"]`
- `NON_PERSISTABLE_DOMAINS = ["battle", "session"]`
- 序列化递归使用 `_deep_copy()` 确保返回的 Dictionary 与内存状态完全解耦（调用方修改不影响 GSM 内部）

### deserialize(data: Dictionary) → bool

```
func deserialize(data: Dictionary) → bool:
  # 1. 结构校验：所有必需域存在？类型匹配？
  if not _validate_save_structure(data):
    push_error("deserialize: invalid save structure")
    return false

  # 2. 逐域反序列化：对缺失字段使用默认值填充
  var snapshot := _state.duplicate(true)
  for domain in ALL_DOMAINS:
    if domain in NON_PERSISTABLE_DOMAINS:
      continue
    if data.has(domain):
      _deserialize_domain(snapshot, domain, data[domain])
    else:
      # 旧版本存档缺少新字段 -> 默认值
      snapshot[domain] = _get_default_for_domain(domain)

  # 3. 原子替换：仅在校验全部通过后替换内存状态
  _state = snapshot
  emit_signal("batch_updated", _build_full_refresh_changes())
  return true
```

**关键设计**:
- 先对拷贝的 snapshot 做所有校验和填充，全部通过后才原子替换 `_state`——保证失败时内存状态不变
- `_get_default_for_domain(domain)` 返回该域完整的默认 Dictionary（与 `_ready()` 初始化逻辑一致）
- `_validate_save_structure(data)` 检查：顶层是 Dictionary；不存在未知顶级域；必需域的值类型匹配
- 旧版本存档缺失 `progression` 域 -> 填充默认值，不报错（向前兼容）

### 存档格式（GSM 侧）

GSM 产生的序列化数据为纯 Dictionary，不含 `schema_version`——Schema 版本由 SaveLoadSystem（ADR-0002）在写入 JSON 时附加：

```
# SaveLoadSystem 包裹 GSM 数据
{
  "schema_version": 1,
  "timestamp": "2026-08-01T12:00:00Z",
  "complete": true,
  "gsm_data": { ... GSM.serialize() 输出 ... }
}
```

`deserialize()` 接收的是已从 JSON 解析的 Dictionary——GSM 不负责 I/O。

---

## QA 测试用例

- **AC-017**: 战斗中序列化排除非持久域
  - Given: `battle != null`，`session` 有数据，`player.cultivation = 500`
  - When: `var data = GSM.serialize()`
  - Then: `data.has("battle") == false`；`data.has("session") == false`；`data.has("player") == true`；`data.player.cultivation == 500`
  - 边界情况: 非战斗状态时序列化结果与战斗中序列化结果比较（player 域值相同）

- **AC-018**: 损坏数据反序列化失败
  - Given: `player.cultivation = 500`（当前内存状态）
  - When: `var ok = GSM.deserialize({})`（空字典——无效存档结构）
  - Then: `ok == false`；`GSM.player.cultivation` 仍为 500（内存状态不变）
  - 边界情况: 部分有效数据 + 部分损坏 -> 整体拒绝，不部分写入

- **AC-019**: 旧版本存档向前兼容
  - Given: 旧存档缺少 `progression` 域
  - When: `var ok = GSM.deserialize(old_data_without_progression)`
  - Then: `ok == true`；`progression` 域被填充为默认值
  - 边界情况: 旧存档中某字段与新类型不兼容 -> 拒绝

---

## 测试证据

**Story 类型**: Logic
**需要证据**: `tests/unit/gsm/serialize_deserialize_test.gd` — 必须存在且通过
**状态**: [ ] 尚未创建

---

## 依赖

- 依赖: Story 002（原子写入方法——序列化需读取当前状态）
- 解锁: Story 005（集成验证——读档后校验状态一致性）