# Story 005: 实例序列化/反序列化 + reconstitute_instances

> **Epic**: card-system
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration（需集成测试）
> **Estimate**: 3h
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-05

## Context

**GDD**: `design/gdd/card-system.md`
**Requirement**: `TR-card-001`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0006（卡牌数据模型——Template/Instance 分离 + Resource 序列化）
**ADR Decision Summary**: CardSystem 提供 `serialize_instance(inst) -> Dictionary` 和 `deserialize_instance(dict) -> CardInstance` 用于存档往返。GSM 持有序列化的 Dictionary（模型 A），通过 `reconstitute_instances(dicts)` 批量重构 CardInstance 对象。`template_id` 经 JSON 往返后需显式 `StringName()` 转换。

**Engine**: Godot 4.6.3 | **Risk**: HIGH（训练截止后 API）
**Engine Notes**: JSON 反序列化产生 String 而非 StringName——`deserialize_instance` 必须执行显式 `StringName(data["template_id"])` 转换，否则 `templates` 字典查找失败。

**Control Manifest Rules (Core 层)**:
- **Required**: GSM 存储序列化的 Dictionary（模型 A）—— 通过 `CardSystem.reconstitute_instances()` 重构
- **Required**: Instance 持有 `template_id: StringName` —— 而非 Resource 引用 —— 存档时只存 template_id 字符串
- **Forbidden**: 绝不将 CardTemplate 序列化进存档（存档只存 template_id + 实例可变状态）

---

## Acceptance Criteria

*From ADR-0006 §CardSystem 公共 API + §GSM 集成合约 + §验证标准:*

- [ ] **AC-001**: `serialize_instance(inst: CardInstance) -> Dictionary`，包含全部 9 字段（card_instance_id、template_id、level、inscriptions、breakthrough_layers、binding_target_id、acquired_chapter、acquired_event_id、acquired_method）
- [ ] **AC-002**: `deserialize_instance(data: Dictionary) -> CardInstance`，恢复全部 9 字段
- [ ] **AC-003**: `deserialize_instance` 对 `template_id` 执行显式 `StringName()` 转换（JSON 反序列化产生 String）
- [ ] **AC-004**: serialize → deserialize 往返保留所有字段值
- [ ] **AC-005**: `reconstitute_instances(dicts: Array) -> Array[CardInstance]`，批量反序列化
- [ ] **AC-006**: 反序列化后 `templates.has(StringName(inst.template_id))` 返回 true（存档往返不破坏字典查找）
- [ ] **AC-007**: `deserialize_instance` 对缺失字段使用 `.get(key, default)` 容错，默认值与 Story 002 一致
- [ ] **AC-008**: 未知字段（9 字段之外的键）忽略，不报错
- [ ] **AC-009**: 类型不匹配字段（如 level 为 String）→ `push_error` + 使用默认值

---

## Implementation Notes

*Derived from ADR-0006 §CardSystem 公共 API + §GSM 集成合约:*

1. **文件位置**: `src/card_system/card_system.gd`（同 Story 003/004，扩展序列化方法）
2. **serialize_instance 实现**（ADR-0006 §CardSystem 公共 API）:
   ```gdscript
   func serialize_instance(inst: CardInstance) -> Dictionary:
       return {
           "card_instance_id": inst.card_instance_id,
           "template_id": inst.template_id,
           "level": inst.level,
           "inscriptions": inst.inscriptions,
           "breakthrough_layers": inst.breakthrough_layers,
           "binding_target_id": inst.binding_target_id,
           "acquired_chapter": inst.acquired_chapter,
           "acquired_event_id": inst.acquired_event_id,
           "acquired_method": inst.acquired_method,
       }
   ```
3. **deserialize_instance 实现**（ADR-0006 §CardSystem 公共 API + AC-007/008/009 容错）:
   ```gdscript
   func deserialize_instance(data: Dictionary) -> CardInstance:
       var inst := CardInstance.new()
       inst.card_instance_id = data.get("card_instance_id", 0)
       inst.template_id = StringName(data.get("template_id", &""))
       inst.level = data.get("level", 1)
       inst.inscriptions = data.get("inscriptions", [])
       inst.breakthrough_layers = data.get("breakthrough_layers", 0)
       inst.binding_target_id = StringName(data.get("binding_target_id", &""))
       inst.acquired_chapter = data.get("acquired_chapter", 0)
       inst.acquired_event_id = StringName(data.get("acquired_event_id", &""))
       inst.acquired_method = data.get("acquired_method", AcquiredMethod.DROP)
       return inst
   ```
4. **StringName 显式转换**（AC-003）: `template_id`、`binding_target_id`、`acquired_event_id` 三个 StringName 字段均需 `StringName()` 转换（JSON 反序列化产生 String）
5. **reconstitute_instances 实现**:
   ```gdscript
   func reconstitute_instances(dicts: Array) -> Array[CardInstance]:
       var result: Array[CardInstance] = []
       for d in dicts:
           result.append(deserialize_instance(d))
       return result
   ```
6. **默认值表**（AC-007，与 Story 002 一致）:
   | 字段 | 默认值 |
   |:--|:--|
   | card_instance_id | 0 |
   | template_id | `&""` |
   | level | 1 |
   | inscriptions | `[]` |
   | breakthrough_layers | 0 |
   | binding_target_id | `&""` |
   | acquired_chapter | 0 |
   | acquired_event_id | `&""` |
   | acquired_method | `AcquiredMethod.DROP` |
7. **未知字段处理**（AC-008）: `deserialize_instance` 只读取已知 9 字段，Dictionary 中其他键被自然忽略（不报错）
8. **类型不匹配处理**（AC-009）: 若 `level` 在 Dictionary 中为 String，Godot 4.6 赋值时会尝试隐式转换；若转换失败（如非数字字符串），`push_error` + 保持默认值。实现时可对关键字段（level、breakthrough_layers、acquired_chapter、acquired_method、card_instance_id）做 `int()` 强制转换 + try/catch 或类型检查

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: CardTemplate Resource 定义
- **Story 002**: CardInstance RefCounted 定义（字段 + 默认值）
- **Story 003**: CardSystem 模板注册表 + get_template（AC-006 依赖）
- **Story 004**: create_instance 实例工厂
- **存档系统完整集成**: SaveLoadSystem 调用 reconstitute_instances 属 SaveLoad Epic（Sprint 1 已部分实现 GSM.serialize/deserialize）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: serialize_instance(inst) -> Dictionary，包含全部 9 字段
  - Given: 构造一个完整 CardInstance，9 字段均赋值（card_instance_id=42、template_id=&"card_s"、level=3、inscriptions=[{"id":1}]、breakthrough_layers=2、binding_target_id=&"char_x"、acquired_chapter=5、acquired_event_id=&"evt_1"、acquired_method=AcquiredMethod.SHOP）
  - When: `var d: Dictionary = cs.serialize_instance(inst)`
  - Then: `assert_eq(d.size(), 9)`；9 个键均存在
  - Edge cases: 确认无多余键；确认 inscriptions 序列化为 Array

- **AC-002**: deserialize_instance(data) -> CardInstance，恢复全部字段
  - Given: AC-001 产生的 Dictionary `d`
  - When: `var inst: CardInstance = cs.deserialize_instance(d)`
  - Then: 9 字段逐一 `assert_eq` 与原值一致
  - Edge cases: inscriptions 数组元素深拷贝（修改反序列化后的数组不影响原 Dictionary）

- **AC-003**: deserialize_instance 对 template_id 执行显式 StringName() 转换
  - Given: 构造 Dictionary，其中 `template_id` 为 String 类型 "card_s"（非 StringName）
  - When: `var inst := cs.deserialize_instance(d)`
  - Then: `assert_eq(typeof(inst.template_id), TYPE_STRING_NAME)`；`assert_eq(inst.template_id, &"card_s")`
  - Edge cases: template_id 已为 StringName → 仍为 StringName；template_id 为 null → 按 AC-007 容错为默认 &""

- **AC-004**: serialize → deserialize 往返保留所有字段值
  - Given: 一个填充的 CardInstance（含边界值：level=0、inscriptions=空数组、breakthrough_layers=0、card_instance_id=2147483647）
  - When: `var d := cs.serialize_instance(inst)`；`var inst2 := cs.deserialize_instance(d)`
  - Then: 9 字段逐一 `assert_eq(inst2.field, inst.field)`
  - Edge cases: level=INT_MAX、card_instance_id=INT_MAX、inscriptions 含 1000 元素

- **AC-005**: reconstitute_instances(dicts) -> Array[CardInstance]，批量反序列化
  - Given: 构造 3 个 CardInstance，分别 serialize 得到 `dicts: Array`（长度 3）
  - When: `var arr: Array[CardInstance] = cs.reconstitute_instances(dicts)`
  - Then: `assert_eq(arr.size(), 3)`；每个元素 `is CardInstance`；各字段与原实例一致
  - Edge cases: 空数组 → 返回空数组（非 null）；单元素数组；返回类型为强类型 `Array[CardInstance]`

- **AC-006**: 反序列化后 templates.has(StringName(inst.template_id)) 返回 true
  - Given: cs.templates 已加载 &"card_s" 模板；构造 inst 并 serialize 得到 d
  - When: `var inst2 := cs.deserialize_instance(d)`
  - Then: `assert_true(cs.templates.has(StringName(inst2.template_id)))`；`assert_eq(typeof(inst2.template_id), TYPE_STRING_NAME)`
  - Edge cases: template_id 经往返仍为 StringName，字典查找命中

- **AC-007**: deserialize_instance 对缺失字段使用 .get(key, default) 容错
  - Given: 构造 Dictionary 仅含 `card_instance_id` 和 `template_id` 两个键（缺其余 7 字段）
  - When: `var inst := cs.deserialize_instance(d)`
  - Then: `assert_eq(inst.card_instance_id, d["card_instance_id"])`；`assert_eq(inst.template_id, d["template_id"])`；其余字段使用默认值：level=1、inscriptions=[]、breakthrough_layers=0、binding_target_id=&""、acquired_chapter=0、acquired_event_id=&""、acquired_method=AcquiredMethod.DROP
  - Edge cases: 完全空 Dictionary → 全默认值，不崩溃

- **AC-008**: 未知字段（9 字段之外的键）忽略，不报错
  - Given: 构造 Dictionary 含 9 字段 + 额外键 `"unknown_field": 123`
  - When: `var inst := cs.deserialize_instance(d)`
  - Then: 9 字段正常恢复；无 push_error；`assert_false(inst.has_method("get_unknown_field"))`（未知键被忽略）
  - Edge cases: 多个未知键同处理

- **AC-009**: 类型不匹配字段 → push_error + 使用默认值
  - Given: 构造 Dictionary，其中 `level` 为 String 类型 "not_a_number"
  - When: `var inst := cs.deserialize_instance(d)`
  - Then: `assert_push_error_count(1)`；`assert_eq(inst.level, 1)`（默认值）；其余字段正常恢复
  - Edge cases: level 为 String "3"（数字字符串）→ 隐式转换为 int 3 或 push_error + 默认值（按实现契约）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/card_system/test_card_serialization.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（CardTemplate）、Story 002（CardInstance 字段定义 + AcquiredMethod 枚举）、Story 003（templates 注册表——AC-006 依赖）
- Unlocks: SaveLoad Epic（reconstitute_instances 用于读档后重构卡牌实例）
