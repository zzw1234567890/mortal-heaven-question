# Story 001: GSM Autoload 基础结构与第一层属性读取

> **Epic**: 游戏状态管理器
> **Status**: In Progress
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2.5h
> **Manifest Version**: 2026-07-26
> **Last Updated**: 2026-07-27

## 上下文

**GDD**: `design/gdd/game-state-manager.md`
**需求**: `TR-gsm-001`

**管辖 ADR**: ADR-0001: 游戏状态管理器 — Autoload 单例 + 三层 API
**ADR 决策摘要**: GSM 占据 Autoload #1，三层 API。`_ready()` 初始化全部 10 个域默认值后发射 `gsm_initialized`。第一层直接属性读取为零拷贝 O(1) 字典访问。

**引擎**: Godot 4.6 | **风险**: MEDIUM

**控制清单规则 (Foundation 层)**:
- 必需: GSM 必须占据 Autoload #1 位置 — `_ready()` 必须先于任何消费者读取完成（ADR-0001）
- 必需: 三层 GSM API — 第一层（直接属性读取——零拷贝 O(1)）（ADR-0001）
- 禁止: 绝不直接写 GSM 属性——始终通过第二层原子方法（ADR-0001）

---

## 验收标准

*来自 GDD:*

- [ ] **AC-001**: GIVEN GSM 初始化完成，WHEN 读取 `player.realm`，THEN 返回默认境界（炼气）
- [ ] **AC-002**: GIVEN GSM 初始化完成，WHEN 读取 `player.resources.ling_shi`，THEN 返回初始灵石数量（>=0）
- [ ] **AC-003**: GIVEN GSM 初始化完成，WHEN 通过 `get("player.realm")` 路径读取境界，THEN 返回值与直接属性读取 `GSM.player.realm` 相同

---

## 实现说明

*来自 ADR-0001 实现指南:*

1. 在 Project Settings 的 `[autoload]` 中将 `GameStateManager` 注册为第一个条目（Autoload #1）
2. `GameStateManager` 类声明为 `extends Node`，在 `_ready()` 中执行：
   - 初始化全部 10 个域（meta、player、collection、deck、battle=null、exploration、narrative、progression、session）及所有嵌套字段为默认值
   - `player.realm` 默认值 = `RealmLevel.QI_REFINING`（炼气，枚举值 1）
   - `player.resources` 初始化为 `{ling_shi: 0, ling_cai: 0, dan_yao_sui_pian: 0}`
   - `player.overflow_pool` 初始化为 0
   - `player.cultivation` 初始化为 0，`player.max_cultivation` 初始化为 1000（`BASE_MAX`）
   - `_initialized = true` 标志位
   - 发射 `gsm_initialized` 信号
3. 第一层属性读取：消费者通过 `GSM.player.realm`、`GSM.player.cultivation` 等直接属性访问——O(1) 字典查找，无信号开销，无拷贝
4. `get(path: String) → Variant` 通用路径读取：以 `.` 分隔的路径逐级访问嵌套字典；路径不存在时返回 null + debug 日志
5. 键名不得包含 `.`（含点的键用下划线替代）
6. 数据树使用嵌套 `Dictionary` 实现，每域为 `Dictionary["String", Variant]`

**引擎特定注意事项**:
- 使用 `Array[String]` 类型化集合（Godot 4.4+，4.5 优化），如 `collection.owned_cards: Array[String]`、`session.input_locks: Array[int]`
- 信号声明使用 Godot 4.0+ `signal` 关键字，加载荷类型化声明

---

## QA 测试用例

- **AC-001**: GSM 初始化完毕可读取默认境界
  - Given: 游戏启动，GSM Autoload `_ready()` 执行完毕
  - When: 任意消费者执行 `var realm = GSM.player.realm`
  - Then: `realm` 等于 `RealmLevel.QI_REFINING`（炼气）
  - 边界情况: `_ready()` 未执行完前读取应看到未初始化值——消费者需检查 `GSM._initialized`

- **AC-002**: GSM 初始化完毕可读取初始灵石
  - Given: 游戏启动，GSM `_ready()` 执行完毕
  - When: 任意消费者执行 `var ling_shi = GSM.get("player.resources.ling_shi")`
  - Then: `ling_shi` >= 0（默认 0）
  - 边界情况: 直接属性读取 vs `get()` 路径读取返回相同值

- **AC-003**: `get(path)` 与直接属性读取一致
  - Given: 游戏启动，GSM `_ready()` 执行完毕
  - When: 执行 `var a = GSM.player.realm` 和 `var b = GSM.get("player.realm")`
  - Then: `a == b`（均为 `RealmLevel.QI_REFINING`）
  - 边界情况: `get("nonexistent.path")` 返回 null + debug 日志，不崩溃

---

## 测试证据

**Story 类型**: Logic
**需要证据**: `tests/unit/gsm/autoload_and_tier1_read_test.gd` — 必须存在且通过
**状态**: [ ] 尚未创建

---

## 依赖

- 依赖: 无（Autoload #1——最先实现）
- 解锁: Story 002（原子写入方法）