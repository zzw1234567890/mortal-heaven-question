# Story 005: 结果执行器 + ADD_CARD 信号委托 —— Foundation 原则 #3 合规

> **Epic**: event-system
> **Story 类型**: Integration（需集成测试）
> **预估工作量**: 4 点
> **依赖**: Story 002（resolve_option）、Story 003（set_flag）、Story 004（连锁事件——集成验证）
> **阻塞**: 无

## 覆盖的 GDD 需求

| TR-ID | 需求描述 | 覆盖方式 |
|-------|---------|---------|
| TR-event-001 | 6 种事件类型 + 60-100 个事件模板的条件分支和结果数据 | `apply_outcomes()` 对 12 种 OutcomeType 执行分发——通过 GSM 第二层原子方法或信号委托 |
| TR-event-002 | story_flags 唯一运行时写入者 + 委托写入契约 | `SET_FLAG` → `EventSystem.set_flag()` 是最终写入路径的集成验证 |

## 管辖 ADR 指南

- ADR-0003 决策 6：`ADD_CARD` 结果通过 `card_reward_requested` 信号委托给 CardSystem——EventSystem（Foundation）不直接调用 CardSystem（Core）——保持 Foundation 层原则 #3 合规
- ADR-0003：`apply_outcomes()` 完成后发射 `event_resolved` 信号——SaveLoad 监听以判定是否触发自动存档
- ADR-0003：`TRIGGER_BATTLE`/`HEAL`/`DAMAGE` —— 由调用方（探索系统/战斗系统）检查 `resolved_outcomes` 字典后自行处理——EventSystem 不直接加载战斗场景
- ADR-0003：`NOTHING` —— 无效果（纯叙事文本）——不计入副作用但仍记入 `resolved_outcomes`
- ADR-0006：CardSystem 监听 `card_reward_requested` 后执行 `create_instance()` + `serialize_instance()` + `GSM.add_card_to_collection()` 完整流程
- ADR-0007：`card_reward_requested` 为 Cat 2c 信号（fire-and-forget 委托信号）——EventSystem 不等待结果

## 控制清单版本

2026-07-26

> Foundation 层规则：
> - ADD_CARD 结果使用信号委托 (`card_reward_requested`) —— EventSystem（Foundation）不直接调用 CardSystem（Core）
> - 所有游戏状态写入必须通过 GSM 第二层原子方法
> - 绝不使用通用 `set(path, value)` —— 使用专用原子方法
> - 绝不发射携带指令（"该做什么"）的信号 —— 信号携带事实（"发生了什么"）
> - Foundation 层原则 #3：Foundation 层系统不得依赖 Core/Feature 层系统

> Core 层规则：
> - CardSystem 是模板注册表 + 实例工厂 —— `create_instance(template_id)` 分配 GSM ID
> - GSM 存储序列化的 Dictionary（模型 A） —— 通过 `CardSystem.reconstitute_instances()` 重构

## 实现范围

### 1. EventSystem.apply_outcomes() —— 结果执行器

```gdscript
## 执行已结算的结果——通过 GSM 第二层原子方法或信号委托
## ⚠️ Foundation 层原则 #3 合规：ADD_CARD → 信号委托，非直接调用 CardSystem
func apply_outcomes(instance: EventInstance) -> void:
    for oc in instance.resolved_outcomes:
        if not oc["triggered"]:
            continue
        match oc["type"]:
            OutcomeType.ADD_RESOURCE:
                GSM.add_resource(oc["target"], oc["value"])
            OutcomeType.ADD_CULTIVATION:
                GSM.add_cultivation(oc["value"])
            OutcomeType.ADD_CARD:
                # ⚠️ 信号委托 —— Foundation 层不直接依赖 Core 层
                card_reward_requested.emit(oc["target"])
            OutcomeType.REMOVE_CARD:
                GSM.remove_card_from_collection(oc["value"])
            OutcomeType.SET_FLAG:
                set_flag(oc["target"], oc["value_str"])
            OutcomeType.RESTORE_AP:
                GSM.restore_action_points(oc["value"])
            OutcomeType.GAIN_TALENT:
                GSM.progression.unlock_talent(oc["target"])
            OutcomeType.ADVANCE_CHAPTER:
                GSM.narrative.advance_chapter(oc["target"])
            OutcomeType.TRIGGER_BATTLE:
                pass  # 由探索系统检查 results 字典后自行处理
            OutcomeType.HEAL, OutcomeType.DAMAGE:
                pass  # 战斗上下文中由战斗系统处理
            OutcomeType.NOTHING:
                pass  # 无效果——仅叙事文本
            _:
                push_warning("EventSystem: unhandled outcome type %d" % oc["type"])

    # 结算完毕后发射——SaveLoad 监听 → 自动存档判定
    event_resolved.emit(instance.template_id, instance.selected_option_index, instance.resolved_outcomes)
```

### 2. card_reward_requested 信号

在 EventSystem 中声明：

```gdscript
signal card_reward_requested(template_id: StringName)
```

**信号契约**：
- EventSystem 发射后不等待任何响应——fire-and-forget（Cat 2c）
- CardSystem 负责监听并执行完整流程
- 如果 CardSystem 未连接（`templates_loaded == false`）→ 卡牌奖励静默丢失

### 3. CardSystem 监听器骨架

在 CardSystem 中实现 `_on_card_reward_requested()`：

```gdscript
## 监听 EventSystem.card_reward_requested 信号
## 完整流程：create_instance → serialize_instance → GSM.add_card_to_collection
func _on_card_reward_requested(template_id: StringName) -> void:
    if not templates_loaded:
        push_error("CardSystem: received card_reward_requested before templates loaded — card '%s' lost" % template_id)
        return

    var inst = create_instance(template_id)
    if inst == null:
        push_error("CardSystem: failed to create instance for template '%s'" % template_id)
        return

    var dict = serialize_instance(inst)
    GSM.add_card_to_collection(dict)
```

**注意**：此监听器**不在本 Story 中完整实现**（CardSystem 属于另一个 Epic）——仅提供骨架以确保信号连接有效。CardSystem 的完整实现由其自身 Story 覆盖。

### 4. GSM 第二层原子方法调用的错误处理

`GSM.add_resource()` 和 `GSM.add_cultivation()` 返回 bool——`apply_outcomes()` 应检查返回值并在失败时记录错误：

```gdscript
OutcomeType.ADD_RESOURCE:
    var ok = GSM.add_resource(oc["target"], oc["value"])
    if not ok:
        push_error("EventSystem: add_resource('%s', %d) failed" % [oc["target"], oc["value"]])
```

### 5. event_resolved 信号

发射时机：`apply_outcomes()` 中所有 Outcome 处理完成后（在方法末尾发射——不仅在循环之后，且在 `push_warning`/`push_error` 之前）

**消费者**：
- SaveLoad：监听 `event_resolved` → 判定是否需要自动存档
- 探索系统：监听 `event_resolved` → 事件结束后恢复地图 UI 控制

## 验收标准

- [ ] **AC-001**: `apply_outcomes()` 中 `ADD_RESOURCE(灵石, 100)` → `GSM.add_resource("灵石", 100)` 被调用且值正确
- [ ] **AC-002**: `apply_outcomes()` 中 `ADD_CULTIVATION(500)` → `GSM.add_cultivation(500)` 被调用且值正确
- [ ] **AC-003**: `apply_outcomes()` 中 `ADD_CARD(card_001)` → `card_reward_requested` 信号发射且携带 `template_id = "card_001"`
- [ ] **AC-004**: `apply_outcomes()` 中 `REMOVE_CARD(42)` → `GSM.remove_card_from_collection(42)` 被调用
- [ ] **AC-005**: `apply_outcomes()` 中 `SET_FLAG("met_boss", "true")` → 通过 `EventSystem.set_flag()` → `GSM.set_narrative_flag("met_boss", "true")` 被调用
- [ ] **AC-006**: `apply_outcomes()` 中 `RESTORE_AP(2)` → `GSM.restore_action_points(2)` 被调用
- [ ] **AC-007**: `apply_outcomes()` 中 `GAIN_TALENT(talent_003)` → `GSM.progression.unlock_talent("talent_003")` 被调用
- [ ] **AC-008**: `apply_outcomes()` 中 `ADVANCE_CHAPTER(chapter_2)` → `GSM.narrative.advance_chapter("chapter_2")` 被调用
- [ ] **AC-009**: `apply_outcomes()` 中 `TRIGGER_BATTLE` → **不**执行任何操作（由探索系统检查 results 后自行加载战斗）
- [ ] **AC-010**: `apply_outcomes()` 中 `HEAL`/`DAMAGE` → **不**执行任何操作（由战斗上下文中的战斗系统处理）
- [ ] **AC-011**: `apply_outcomes()` 中 `NOTHING` → 不执行任何操作但仍计入 `resolved_outcomes`（计数器验证）
- [ ] **AC-012**: `apply_outcomes()` 中 `chance < 1.0` 未触发的 outcome → `triggered=false` 项被跳过不执行
- [ ] **AC-013**: 所有 Outcome 结算完成后 `event_resolved` 信号发射
- [ ] **AC-014**: `event_resolved` 信号携带 `event_id`、`option_idx`、`outcomes` 三个参数
- [ ] **AC-015**: `card_reward_requested` 信号被 CardSystem 监听 → CardSystem 正确调用 `create_instance()` + `serialize_instance()` + `GSM.add_card_to_collection()`
- [ ] **AC-016**: EventSystem **不直接导入或调用** CardSystem 的任何方法（代码审查——grep `CardSystem` 在 `event_system.gd` 中不存在直接调用）
- [ ] **AC-017**: `GSM.add_resource()` 返回 false 时 `apply_outcomes()` 记录 `push_error` 而非静默失败
- [ ] **AC-018**: 未处理的 OutcomeType 枚举值触发 `push_warning`
- [ ] **AC-019**: 集成测试：完整事件流（trigger → resolve → apply_outcomes → chain → resolve → apply_outcomes → end）中所有结果正确执行

## 测试证据路径

| 证据类型 | 位置 |
|---------|------|
| 单元测试 | `tests/unit/event_system/apply_outcomes_test.gd` |
| 集成测试 | `tests/integration/event_system/card_reward_delegation_test.gd` |
| 集成测试 | `tests/integration/event_system/full_event_flow_test.gd` |

## 实现注意事项

- `apply_outcomes()` **不在** Story 002 的 `resolve_option()` 中自动调用——调用方（探索系统/UI 控制器）显式调用，允许在结算前插入 UI 动画
- `card_reward_requested` 是 fire-and-forget（Cat 2c）——EventSystem 不等待 CardSystem 响应，不处理失败
- CardSystem 监听器骨架仅验证**信号连接可用**——完整实现属于 CardSystem Epic
- `TRIGGER_BATTLE`/`HEAL`/`DAMAGE` 不在 EventSystem 中执行——由调用方检查 `resolved_outcomes` 字典后自行处理
- `GSM.add_resource()` 和 `GSM.add_cultivation()` 的返回值必须检查——失败时记录错误
- 使用 `match` 语句而非 if-elif 链——GDScript 编译器对 enum match 优化更好，且新增枚举值时编译器会警告未覆盖的分支
- 所有 GSM 第二层方法调用必须通过其**专用方法名**——不使用通用 `GSM.set()` 或直接写属性
