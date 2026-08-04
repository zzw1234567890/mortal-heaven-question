# Story 003: story_flags 唯一运行时写入者 —— 委托写入契约

> **Status**: Complete
> **Last Updated**: 2026-08-03
> **Epic**: event-system
> **Story 类型**: Logic + Integration（需单元测试 + 集成测试）
> **预估工作量**: 3 点
> **依赖**: Story 002（EventSystem Autoload 骨架——模板注册表、trigger_event、check_condition）
> **阻塞**: Story 005（set_flag 写入路径的最终集成）

## 覆盖的 GDD 需求

| TR-ID | 需求描述 | 覆盖方式 |
|-------|---------|---------|
| TR-event-002 | story_flags 唯一运行时写入者 + 委托写入契约 | `EventSystem.set_flag()` 为唯一写入入口；`GSM.set_narrative_flag()` 为 GSM 第二层新增原子方法；剧情/对话/效果引擎通过 EventSystem 委托写入 |

## 管辖 ADR 指南

- ADR-0003 决策 3：EventSystem 是 `story_flags` 的**唯一运行时写入者**——所有其他系统通过 `EventSystem.set_flag()` 委托写入，不直接操作 `GSM.narrative.story_flags`
- ADR-0003：需在 ADR-0001 中新增 GSM 第二层原子方法 `set_narrative_flag(flag: StringName, value: Variant) → void`
- ADR-0003：`flag_changed` **不作为 EventSystem 独立信号**——通过 GSM 的 `batch_updated` 承载（路径 `"narrative.story_flags.{key}"`），消费者通过路径前缀过滤
- ADR-0007：信号声明在语义归属系统——禁止 SignalBus Autoload

## 控制清单版本

2026-07-26

> Foundation 层规则：
> - `story_flags` 的唯一运行时写入者是 EventSystem —— 所有其他系统通过 `EventSystem.set_flag()` 委托写入
> - 绝不使用通用 `set(path, value)` —— 使用专用原子方法
> - 绝不直接写 GSM 属性 —— 始终通过第二层原子方法
> - 信号命名：snake_case 过去式
> - 信号载荷：≤3 参数优先

> Narrative 层规则：
> - `story_flags` 写入委托给 `EventSystem.set_flag()` —— 遵守唯一写入者契约
> - 绝不让 StorySystem 或 DialogueSystem 直接写 `story_flags`

> 禁止方法：
> - 绝不让 DialogueSystem/StorySystem/CardEffectEngine 直接写 `story_flags` —— 委托给 `EventSystem.set_flag()`

## 实现范围

### 1. GSM 第二层新增方法

在 GSM 中新增 `set_narrative_flag()`（参见 ADR-0003 接口契约）：

```gdscript
## 供 EventSystem 使用——不得由剧情/对话/效果引擎直接调用
## 调用方：EventSystem.set_flag()（唯一写入入口）
func set_narrative_flag(flag: StringName, value: Variant) -> void:
    var old = narrative.story_flags.get(flag, null)
    if old == value:
        return
    narrative.story_flags[flag] = value
    # 使用 GSM 第二层标准缓冲路径（_buffer_change → 帧末 _flush_pending_changes → batch_updated），
    # 与 add_resource / set_identity 等既有第二层方法保持模式一致——不直接 emit batch_updated。
    _buffer_change("narrative.story_flags.%s" % flag, old, value)
```

**关键约束**：
- 相同值重复写入 → 不缓冲变更、不发射 `batch_updated`（去重，由调用点 `if old == value: return` 保证）
- `batch_updated` 携带展平路径字典 `{"narrative.story_flags.{key}": {old, new}}`（由 `_flush_pending_changes` 统一发射）
- `flag_changed` **不作为 EventSystem 独立信号**——GSM `batch_updated` 是唯一传播渠道

### 2. EventSystem.set_flag() —— 唯一写入入口

```gdscript
## story_flags 唯一运行时写入入口
func set_flag(key: String, value: Variant) -> void:
    GSM.set_narrative_flag(key, value)
```

**注意**：此方法仅一行委托——但其存在是架构合规的核心。任何系统（剧情/对话/效果引擎）需写入 `story_flags` 时，必须调用 `EventSystem.set_flag()`，而**不可**调用 `GSM.set_narrative_flag()` 或直接写 `GSM.narrative.story_flags`。

### 3. EventSystem.get_flag() —— 只读查询（任意系统可用）

```gdscript
## 任意系统可读——无写入权限制
func get_flag(key: String, default: Variant = false) -> Variant:
    return GSM.narrative.story_flags.get(key, default)
```

### 4. 委托写入契约文档化

在 `EventSystem.set_flag()` 的文档注释中明确记录委托链：

```
委托写入合约：
┌─ EventSystem.set_flag(key, value) ← 唯一写入入口
│   └→ GSM.set_narrative_flag(key, value) ← GSM 第二层新增
│        ├→ 写入 GSM.narrative.story_flags[key]
│        └→ 发射 batch_updated（SaveLoad 监听 → 自动存档判定）
│
├─ 剧情系统 (StorySystem):
│   advance_chapter(chapter_id)
│     └→ EventSystem.set_flag("chapter_" + chapter_id, true)  ✅
│     不可直接: GSM.narrative.story_flags[key] = value  ❌
│
├─ 对话系统 (DialogueSystem):
│   DialogueOutcome.set_flag
│     └→ EventSystem.set_flag(outcome.target, outcome.value)  ✅
│
├─ 卡牌效果引擎 (CardEffectEngine):
│   SET_FLAG 效果类型
│     └→ EventSystem.set_flag(effect.flag_key, true)  ✅
│
└─ 结局分支系统 (EndingSystem):
    只读: EventSystem.get_flag(key) —— 不写入
```

### 5. 消费者通过 batch_updated 过滤 story_flags 变更

剧情/对话/结局系统监听 GSM `batch_updated` 信号，通过路径前缀过滤 `narrative.story_flags.*` 来检测 flag 变更：

```gdscript
func _on_batch_updated(changes: Dictionary) -> void:
    for path in changes:
        if path.begins_with("narrative.story_flags."):
            var flag_key = path.trim_prefix("narrative.story_flags.")
            var delta = changes[path]
            _on_flag_changed(flag_key, delta["old"], delta["new"])
```

## 验收标准

- [ ] **AC-001**: `EventSystem.set_flag("chapter_1", true)` → `GSM.narrative.story_flags["chapter_1"] == true`
- [ ] **AC-002**: `EventSystem.set_flag("chapter_1", true)` 两次连续调用（相同值）→ 第二次不发射 `batch_updated`
- [ ] **AC-003**: `EventSystem.set_flag("met_boss", false)` → `GSM.narrative.story_flags["met_boss"] == false`
- [ ] **AC-004**: `EventSystem.get_flag("non_existent", false)` 返回 `false`（默认值）
- [ ] **AC-005**: `EventSystem.get_flag("chapter_1", false)` 对已设置的 flag 返回 `true`
- [ ] **AC-006**: `GSM.set_narrative_flag("flag_a", "value_1")` 写入后 `batch_updated` 携带路径 `"narrative.story_flags.flag_a"` 的变更字典 `{old: null, new: "value_1"}`
- [ ] **AC-007**: `GSM.set_narrative_flag("flag_a", "value_2")` 更新后 `batch_updated` 携带 `{old: "value_1", new: "value_2"}`
- [ ] **AC-008**: 集成测试验证：外部调用方通过 `EventSystem.set_flag()` 写入后 `GSM.narrative.story_flags` 被正确更新，且 stub 调用方不直接访问 `GSM.narrative.story_flags`（完整消费者合规性验证——StorySystem/DialogueSystem/CardEffectEngine——延后至 Story 005 集成测试）
- [ ] **AC-009**: 代码审查检查点：整个代码库中（排除 EventSystem 自身）不存在 `GSM.narrative.story_flags[` 的直接赋值（注：Story 003 阶段平凡通过——仅 Foundation 层代码存在；Story 005 及后续 sprint 重新验证）
- [ ] **AC-010**: `set_flag()` 是 EventSystem 的唯一公开写入方法——其他系统的 set_flag 通过它委托
- [ ] **AC-011**: `get_flag()` 可被任意系统安全调用——不产生副作用、不发射信号

## 测试证据路径

| 证据类型 | 位置 |
|---------|------|
| 单元测试 | `tests/unit/event_system/test_set_flag.gd` |
| 单元测试 | `tests/unit/event_system/test_get_flag.gd` |
| 单元测试 | `tests/unit/gsm/test_set_narrative_flag.gd` |
| 集成测试 | `tests/integration/event_system/test_story_flags_delegation.gd` |

## 实现注意事项

- `GSM.set_narrative_flag()` 需在 ADR-0001 中补充——新增第二层原子方法
- `flag_changed` **不是** EventSystem 的独立信号——不要声明它。通过 GSM `batch_updated` 承载
- `set_flag()` 重复写入相同值时不发射信号——减少 SaveLoad 误触发自动存档
- `set_flag()` 的参数签名：`key: String, value: Variant` —— Variant 仅在接口处使用（参数），不在 Resource `@export` 中使用
- 剧情/对话/效果引擎的写入合规性是**架构审查检查点**——在 Story 005 集成测试中验证

## Completion Notes
**Completed**：2026-08-03
**Criteria**：11/11 通过（全部自动验证）
**Deviations**：
- ADVISORY（测试命名偏差）：`.gutconfig.json` 强制 `prefix: "test_"`，实际测试文件用 `test_` 前缀（如 `test_set_flag.gd`），而非故事证据路径原列的后缀命名（如 `set_flag_test.gd`）。已更新本文件证据路径表匹配实际文件名。
- ADVISORY（AC-008/009 延后）：完整消费者合规性验证（StorySystem/DialogueSystem/CardEffectEngine）延后至 Story 005 集成测试。Story 003 用 stub 验证委托路径可达，AC-009 grep 检查点在当前阶段平凡通过（仅 Foundation 层代码存在）。
- ADVISORY（LOW-1 ADR 文本过时）：ADR-0003 第 375-387 行代码示例展示直接 `batch_updated.emit(changes)`，实际实现使用 `_buffer_change` 缓冲路径（符合 ADR-0001 第二层契约，更优）。ADR 文本应单独更新以反映实际缓冲路径。
- ADVISORY（LOW-6 测试访问私有成员）：测试直接操作 GSM `_pending_changes`/`_flush_scheduled` 私有成员做隔离清理——Autoload 单例测试的务实折中，未来可加 `_reset_for_testing()` 封装。
- ADVISORY（qa-tester 缺口 1/2 未补）：Variant 跨类型去重语义、同帧多次写入缓冲合并载荷两项边缘测试未补充（非阻塞，建议后续 sprint 补）。
**Test Evidence**：Logic+Integration 故事，4 个测试文件 18 个测试函数覆盖 AC-001~011，全部通过。全量套件 451/452 通过（1 既有 pending migration_chain），零失败。
**Code Review**：已完成——code-reviewer（godot-gdscript-specialist）APPROVED WITH SUGGESTIONS（0 BLOCKER / 0 HIGH / 9 LOW）。已修 LOW-2/3/4（`_buffer_change`/`_emit_domain_signal`/`_check_faction_condition`/`_check_flag_set_condition` 的 `var flags`/`old_val`/`new_val` 加 `: Variant` 注解）+ LOW-5（`_check_faction_condition` 注释更新指向 ADR-0022 身份选择系统）+ 补 qa-tester 缺口 3（story_flags 不误发域信号防护测试）。LOW-1/6/7/8/9 记录为 ADVISORY。LP-CODE-REVIEW 关卡复用此审查结果。
**QL-TEST-COVERAGE**：ADEQUATE——18 个测试函数实质覆盖全部 11 条 AC。AC-002 时序断言可靠（数据写入在 _buffer_change 前，同步去重），AC-006/007 batch_updated 载荷路径与 old/new 正确，AC-009 grep 检查点诚实标注平凡通过。
