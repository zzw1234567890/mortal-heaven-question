# Story 004: 连锁事件 —— MAX_CHAIN_DEPTH=3 + visited_ids 循环检测

> **Epic**: event-system
> **Story 类型**: Logic（需 GUT 单元测试）
> **预估工作量**: 3 点
> **依赖**: Story 002（EventInstance + trigger_event）
> **阻塞**: Story 005（连锁事件通过 apply_outcomes 结算的集成验证）

## 覆盖的 GDD 需求

| TR-ID | 需求描述 | 覆盖方式 |
|-------|---------|---------|
| TR-event-001 | 6 种事件类型 + 60-100 个事件模板的条件分支和结果数据 | 连锁事件链是事件模板的 `chain_next` + `chain_on_option` 字段的运行时解析 |

GDD 边界情况：
- 连锁事件嵌套超过 3 层 → 系统在 3 层后强制截断（最后层自动执行 `nothing`）
- 连锁事件链中不消耗额外行动力（调用方保证）

## 管辖 ADR 指南

- ADR-0003 决策 5：连锁事件——MAX_CHAIN_DEPTH=3 硬限制 + `visited_ids` 集合循环检测 + 非静默日志（`push_warning`）
- ADR-0003：`chain_triggered.emit(from, to)` 和 `chain_ended.emit(final_id)` 信号——UI 监听前者（面板内容替换），探索系统监听后者（恢复地图控制）
- ADR-0003：循环检测算法——调用方维护 `_chain_visited_ids` 集合，在每次 `trigger_event()` 前调用 `_check_chain_cycle()`

## 控制清单版本

2026-07-26

> Foundation 层规则：
> - 连锁事件：MAX_CHAIN_DEPTH = 3 + `visited_ids` 循环检测
> - 信号声明在语义归属系统——禁止 SignalBus Autoload
> - 信号载荷：≤3 参数优先

## 实现范围

### 1. 连锁事件核心逻辑

在 `EventSystem` 中实现：

#### `get_chain_event(instance: EventInstance, option_index: int) -> StringName`

1. 获取模板：`templates.get(instance.template_id)`
2. 模板不存在或 `chain_next == &""`：返回空 `&""`
3. 检查 `chain_on_option`：
   - `chain_on_option >= 0` 且 `chain_on_option != option_index`：返回空 `&""`（仅指定选项触发连锁）
   - `chain_on_option = -1`：任意选项均可触发
4. 深度限制：`instance.chain_depth >= MAX_CHAIN_DEPTH(=3)` → `push_warning` + 返回空 `&""`
5. 返回 `template.chain_next`

#### `_check_chain_cycle(instance: EventInstance, next_id: StringName) -> bool`

1. `_chain_visited_ids.has(next_id)` → `push_warning` + 发射 `chain_ended.emit(instance.template_id)` + 清空 `_chain_visited_ids` + 返回 `false`
2. `_chain_visited_ids.append(next_id)` + 返回 `true`

### 2. 调用方标准模式

在文档注释中提供调用方（通常为探索系统或事件 UI 控制器）的标准循环模式：

```gdscript
# 调用方代码模板
var visited_ids: Array[StringName] = []
var current_instance = event_system.trigger_event(start_event_id)
var chain_depth = 0

while true:
    # 展示事件、等待玩家选择...
    var chosen_option = await player_choice  # 玩家选择选项索引

    var results = event_system.resolve_option(current_instance, chosen_option)
    event_system.apply_outcomes(current_instance)

    var next_id = event_system.get_chain_event(current_instance, chosen_option)
    if next_id == &"":
        break

    if not event_system._check_chain_cycle(current_instance, next_id):
        break

    if chain_depth >= event_system.MAX_CHAIN_DEPTH:
        event_system.push_warning("chain depth exceeded")
        event_system.chain_ended.emit(current_instance.template_id)
        break

    event_system.chain_triggered.emit(current_instance.template_id, next_id)
    var next_instance = event_system.trigger_event(next_id)
    next_instance.chain_depth = chain_depth + 1
    current_instance = next_instance
    chain_depth += 1
```

### 3. 信号

在 EventSystem 中声明（Story 002 中已定义，本 Story 实现其发射逻辑）：
- `chain_triggered(from_event: StringName, to_event: StringName)` —— 连锁触发时发射
- `chain_ended(final_event_id: StringName)` —— 链结束（无 chain_next 或深度截断或循环检测命中）时发射

### 4. 常量

```gdscript
const MAX_CHAIN_DEPTH: int = 3
```

## 验收标准

- [ ] **AC-001**: `chain_depth = 3` 时 `get_chain_event()` 返回空 StringName——截断生效
- [ ] **AC-002**: `chain_depth = 2` 且模板有 `chain_next` 时 `get_chain_event()` 返回下一个模板 ID——正常延续
- [ ] **AC-003**: `chain_depth = 3` 截断时 `push_warning` 被调用（日志可见）
- [ ] **AC-004**: 循环场景 A→B→A：`_check_chain_cycle()` 在第三次触发时返回 false（`visited_ids` 检测到重复）+ `push_warning`
- [ ] **AC-005**: `chain_on_option = 1` 时仅选项索引 1 触发连锁，选项索引 0 的 `get_chain_event()` 返回空 `&""`
- [ ] **AC-006**: `chain_on_option = -1` 时任意选项均可触发连锁
- [ ] **AC-007**: `chain_next = &""`（空）时 `get_chain_event()` 返回空 `&""`
- [ ] **AC-008**: 模板不存在时 `get_chain_event()` 安全返回空 `&""`——不崩溃
- [ ] **AC-009**: `chain_triggered.emit(from, to)` 在有效连锁触发前发射
- [ ] **AC-010**: `chain_ended.emit(final_id)` 在以下场景均发射：(a) 无 chain_next (b) 深度截断 (c) 循环检测命中
- [ ] **AC-011**: `_chain_visited_ids` 在循环检测命中后清空（防止后续独立事件链受影响）
- [ ] **AC-012**: 连锁事件链中不消耗额外行动力——调用方行为：`chain_depth` 增加不触发 `exploration.consume_action_point()`

## 测试证据路径

| 证据类型 | 位置 |
|---------|------|
| 单元测试 | `tests/unit/event_system/chain_event_depth_test.gd` |
| 单元测试 | `tests/unit/event_system/chain_event_cycle_test.gd` |
| 单元测试 | `tests/unit/event_system/chain_event_option_filter_test.gd` |

## 实现注意事项

- `MAX_CHAIN_DEPTH = 3` 是调优参数——使用常量而非硬编码，便于后续调整（安全范围 1-5）
- `_chain_visited_ids` 在 `_check_chain_cycle()` 返回 false 后**必须清空**——否则影响后续独立事件链
- 循环检测是**纵深防御**——主防御是 `MAX_CHAIN_DEPTH` 硬限制
- `push_warning` 用于截断和循环场景——问题可诊断（非静默）
- `chain_triggered` 信号由 UI 系统监听——用于面板内容替换（参考 GDD §用户界面需求 §连锁事件提示）
- `chain_ended` 信号由探索系统监听——用于恢复地图控制
