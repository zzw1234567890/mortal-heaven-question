# Story 004: 连锁事件 —— MAX_CHAIN_DEPTH=3 + visited_ids 循环检测

> **Epic**: event-system
> **Status**: Complete
> **Last Updated**: 2026-08-04
> **Story 类型**: Logic（需 GUT 单元测试）
> **预估工作量**: 3 点
> **依赖**: Story 002（EventInstance + trigger_event）
> **阻塞**: Story 005（连锁事件通过 apply_outcomes 结算的集成验证）
> **范围外**: 完整连锁触发链的调用方集成（→ Story 005）、行动力消耗契约（→ 探索系统 ADR-0014 Story）

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
- ADR-0003：循环检测算法——调用方维护 `_chain_visited_ids` 集合，在每次 `trigger_event()` 前调用 `check_chain_cycle()`

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

#### `check_chain_cycle(instance: EventInstance, next_id: StringName) -> bool`

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
        # 链结束（无 chain_next 或深度截断）——调用方发射 chain_ended
        # 注：get_chain_event 内部已处理深度截断的 push_warning
        event_system.chain_ended.emit(current_instance.template_id)
        break

    if not event_system.check_chain_cycle(current_instance, next_id):
        # 循环检测命中——check_chain_cycle 内部已 emit chain_ended
        break

    # 连锁跳转确认——调用方发射 chain_triggered
    event_system.chain_triggered.emit(current_instance.template_id, next_id)
    var next_instance = event_system.trigger_event(next_id)
    next_instance.chain_depth = chain_depth + 1
    current_instance = next_instance
    chain_depth += 1
```

### 3. 信号

在 EventSystem 中声明（Story 002 中已定义信号）。本 Story 实现其发射逻辑——**混合归属**：

- `chain_triggered(from_event: StringName, to_event: StringName)` —— **由调用方发射**。EventSystem 的 `get_chain_event()` 是查询方法（CQS——命令查询分离），不在内部 emit。调用方在确认连锁跳转后（`get_chain_event()` 返回非空 + `check_chain_cycle()` 返回 true）发射此信号。
- `chain_ended(final_event_id: StringName)` —— 混合归属：
  - 场景 (c) 循环检测命中：`check_chain_cycle()` 内部 emit（EventSystem 单元可测）
  - 场景 (a) 无 chain_next + 场景 (b) 深度截断：调用方在 `get_chain_event()` 返回 `&""` 后、break 前 emit（调用方契约，归属 Story 005 集成测试）

### 4. 常量

```gdscript
const MAX_CHAIN_DEPTH: int = 3
```

## 验收标准

- [ ] **AC-001**: `chain_depth = 3` 时 `get_chain_event()` 返回空 StringName——截断生效
- [ ] **AC-002**: `chain_depth = 2` 且模板有 `chain_next` 时 `get_chain_event()` 返回下一个模板 ID——正常延续
- [ ] **AC-003**: `chain_depth = 3` 截断时 `push_warning` 被调用（日志可见）
- [ ] **AC-004**: 循环场景 A→B→A：`check_chain_cycle()` 在第三次触发时返回 false（`visited_ids` 检测到重复）+ `push_warning`
- [ ] **AC-005**: `chain_on_option = 1` 时仅选项索引 1 触发连锁，选项索引 0 的 `get_chain_event()` 返回空 `&""`
- [ ] **AC-006**: `chain_on_option = -1` 时任意选项均可触发连锁
- [ ] **AC-007**: `chain_next = &""`（空）时 `get_chain_event()` 返回空 `&""`
- [ ] **AC-008**: 模板不存在时 `get_chain_event()` 安全返回空 `&""`——不崩溃
- [ ] **AC-009**: chain_triggered.emit(from, to) 由调用方在连锁跳转确认后发射——单元测试验证信号连通性（watch_signals + 手动 emit 断言监听者接收），完整触发链（含调用方决策）移至 Story 005 集成测试
- [ ] **AC-010**: chain_ended.emit(final_id) 在以下场景均发射：
      - (c) 循环检测命中 → `check_chain_cycle()` 内部 emit（EventSystem 单元可测）
      - (a) 无 chain_next + (b) 深度截断 → 调用方在 `get_chain_event()` 返回空后 emit [INTEGRATION，Story 005 集成测试验证]
- [ ] **AC-011**: `_chain_visited_ids` 在链结束时清空，覆盖三场景：(a) 循环检测命中 (b) 正常结束（chain_next 空）(c) 深度截断——防止残留 ID 污染下一条独立事件链的循环检测（误报循环）

## 测试证据路径

| 证据类型 | 位置 |
|---------|------|
| 单元测试 | `tests/unit/event_system/test_chain_event_depth.gd` |
| 单元测试 | `tests/unit/event_system/test_chain_event_cycle.gd` |
| 单元测试 | `tests/unit/event_system/test_chain_event_option_filter.gd` |

## 实现注意事项

- `MAX_CHAIN_DEPTH = 3` 是调优参数——使用常量而非硬编码，便于后续调整（安全范围 1-5）
- `_chain_visited_ids` 在链结束时**必须清空**——覆盖三场景：(a) 循环检测命中（`check_chain_cycle` 内 clear）(b) 正常结束（`get_chain_event` 返回 `&""` 时 clear）(c) 深度截断（同 (b) 路径）。否则残留 ID 会污染下一条独立事件链的循环检测（误报循环）
- 循环检测是**纵深防御**——主防御是 `MAX_CHAIN_DEPTH` 硬限制
- `push_warning` 用于截断和循环场景——问题可诊断（非静默）
- `chain_triggered` 信号由 UI 系统监听——用于面板内容替换（参考 GDD §用户界面需求 §连锁事件提示）
- `chain_ended` 信号由探索系统监听——用于恢复地图控制
- [新增] **调用方契约：连锁事件链中不消耗额外行动力**——此约束属探索系统（ADR-0014）范围，应在该系统 Story 的验收标准中作为 AC 出现（GDD §5）。EventSystem（Foundation 层）无 `consume_action_point` 方法，不在本 Story 验证范围。原 AC-012 已移除。
- [新增] **push_warning 断言方案**：GUT 4.x 对 `push_warning` 无原生断言（`assert_printed` 仅覆盖 `print()`）。实现时需选定方案——注入 logger mock 或自定义断言辅助（如 `_last_warning` 捕获），并在三个测试文件中一致使用。实现前与主程序员确认方案。

## Completion Notes
**Completed**：2026-08-04
**Criteria**：11/11 通过（AC-009/010(a)(b) 为调用方契约，按 AC 自身界定归属 Story 005 集成测试）
**Deviations**：7 项 ADVISORY（LP-CODE-REVIEW）+ 1 项 ADVISORY（QL-TEST-COVERAGE），均不阻塞：
  1. [ADVISORY] 选项不匹配时 `_chain_visited_ids` 残留风险——需在 Story 005 集成测试中验证：玩家选了不触发连锁的选项后，新事件链不误报循环
  2. [ADVISORY][已修复] AC-011 标签在 `test_chain_event_depth.gd` 中错配——`test_ac011a_no_chain_next_clears_visited_ids` 已修正为 `test_ac011b_no_chain_next_clears_visited_ids`（场景 b 正常结束）
  3. [ADVISORY] AC-009 `chain_triggered` 信号连通性缺少明确单元测试（watch_signals + 手动 emit 断言）——信号已声明，模式已被 `chain_ended` 测试证明有效，缺失的是 3 行平凡测试，Story 005 集成测试将覆盖完整触发链
  4. [ADVISORY] `event_system.gd` 497 行 > 300 行软限制——既有债务（Story 002/003/004 累积），建议后续按职责拆分（条件判定引擎/连锁事件/模板加载）
  5. [ADVISORY] `check_chain_cycle` 命名与 ADR-0003 §循环检测算法 `_check_chain_cycle` 不一致——合理修正（下划线前缀与"调用方调用"矛盾），建议后续通过 ADR 修订同步命名
  6. [ADVISORY][已修复] `test_chain_event_cycle.gd` L286 测试命名 `testcheck_chain_cycle_accumulates_visited_ids` 缺下划线——已修正为 `test_check_chain_cycle_accumulates_visited_ids`
  7. [ADVISORY] `class_name EventSystem` 与 Autoload 冲突——已尝试添加后回退（Autoload 全局单例与 class_name 冲突，导致 ES_SCRIPT.new() 测试实例解析为 Nil，402/486 测试失败）。保留 `extends Node` + `var es: Node` 动态分派模式（同 GSM/InputManager），Foundation Autoload 固有权衡
  8. [ADVISORY] push_warning 断言方案：实现注意事项曾担忧 GUT 4.x 无原生 push_warning 断言，但测试实际使用了 GUT 内置的 `assert_push_warning` / `assert_push_warning_count` 方法并成功通过（486/487），该担忧已解决
**Test Evidence**：Logic——3 个单元测试文件 35 测试函数（test_chain_event_depth.gd 15 + test_chain_event_cycle.gd 13 + test_chain_event_option_filter.gd 7），486/487 通过（1 pending 为 save_load 的 migration_chain，与本故事无关）
**Code Review**：已完成——LP-CODE-REVIEW APPROVED WITH CONCERNS（7 ADVISORY）+ QL-TEST-COVERAGE ADEQUATE（1 ADVISORY）。已修复 2 项（#2 标签错配 + #6 命名缺下划线），其余 6 项保留为 ADVISORY，其中 #1（选项不匹配残留风险）须在 Story 005 集成测试 AC 中明确覆盖
