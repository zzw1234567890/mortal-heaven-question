# Story 002: CardInstance RefCounted 实例模型

> **Epic**: card-system
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic（需 GUT 单元测试）
> **Estimate**: 2.5h
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-05

## Context

**GDD**: `design/gdd/card-system.md`
**Requirement**: `TR-card-001`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0006（卡牌数据模型——Template/Instance 分离 + Resource 序列化）
**ADR Decision Summary**: CardInstance 为 RefCounted 运行时可变实例，持有 `template_id: StringName`（非 Resource 引用）+ 独立的成长状态字段。同名卡的不同实例等级独立——编译时强制执行实例隔离。

**Engine**: Godot 4.6.3 | **Risk**: HIGH（训练截止后 API）
**Engine Notes**: RefCounted 自动引用计数管理生命周期；StringName 字段存档往返需显式 `StringName()` 转换（JSON 反序列化产生 String）。

**Control Manifest Rules (Core 层)**:
- **Required**: CardInstance 持有 `template_id: StringName` —— 而非 Resource 引用 —— 通过 `CardSystem.get_template(id)` 查询
- **Required**: CardInstance 持有 `card_instance_id: int` —— 由 GSM 分配全局唯一 ID
- **Forbidden**: 绝不运行时写 CardTemplate 字段（实例只持有 template_id 引用）

---

## Acceptance Criteria

*From GDD `design/gdd/card-system.md` §详细设计 #1 CardInstance 附加字段 + §验收标准——实例独立性:*

- [ ] **AC-001**: CardInstance extends RefCounted，声明 `class_name CardInstance`
- [ ] **AC-002**: `card_instance_id: int` 字段（默认 0，由 GSM 分配单调递增 ID）
- [ ] **AC-003**: `template_id: StringName` 字段（指向 CardTemplate.card_id，默认 `&""`）
- [ ] **AC-004**: 成长状态字段：`level: int`（默认 1）、`inscriptions: Array[Dictionary]`（默认空数组）、`breakthrough_layers: int`（默认 0）
- [ ] **AC-005**: 绑定字段：`binding_target_id: StringName`（默认 `&""` 表示未绑定）
- [ ] **AC-006**: 获得来源字段：`acquired_chapter: int`（默认 0）、`acquired_event_id: StringName`（默认 `&""`）、`acquired_method: int`（默认 `AcquiredMethod.DROP`）
- [ ] **AC-007**: 两张同名卡 CardInstance 实例的 `level` 独立——修改实例 A 的 level 不影响实例 B
- [ ] **AC-008**: `AcquiredMethod` 枚举定义（独立枚举文件 `src/card_system/acquired_method.gd`），含 5 个值：DROP / SHOP / EVENT / CRAFT / TRIBULATION

---

## Implementation Notes

*Derived from ADR-0006 §CardInstance（实例层）—— RefCounted, 运行时分配:*

1. **文件位置**:
   - `src/card_system/card_instance.gd`（CardInstance 类）
   - `src/card_system/acquired_method.gd`（AcquiredMethod 独立枚举——qa-lead 提示明确宿主，便于测试导入）
2. **类声明**: `class_name CardInstance` + `extends RefCounted`
3. **实例 ID 分配**: `card_instance_id` 默认 0（未分配状态），由 Story 004 的 `CardSystem.create_instance()` 调用 `GSM.allocate_card_id()` 填充。本 Story 仅定义字段。
4. **`inscriptions: Array[Dictionary]`**: 强类型数组（qa-lead 提示——避免裸 Array 与 AC-010 精神冲突）。元素为铭刻副属性 Dictionary，结构由 InscriptionSystem Epic（ADR-0030）定义，本 Story 仅声明容器。
5. **`template_id` 而非 Resource 引用**: 实例持有 StringName 引用，通过 `CardSystem.get_template(inst.template_id)` 查询模板。避免两层引用耦合——Instance 可在未加载模板时被序列化/反序列化。
6. **实例独立性**: RefCounted 每次 `new()` 分配独立对象，字段互不影响。AC-007 是关键行为断言——验证 RefCounted 实例隔离性。
7. **不声明 class_name 冲突**: CardInstance 不是 Autoload，声明 `class_name` 安全。
8. **AcquiredMethod 独立枚举**: 避免循环依赖（CardInstance 引用 CardTemplate 枚举，但 AcquiredMethod 是卡牌独有概念，不应塞入 CardTemplate）。独立文件 `acquired_method.gd` 声明 `class_name AcquiredMethod` + `enum { DROP, SHOP, EVENT, CRAFT, TRIBULATION }`。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: CardTemplate Resource + CardType/Rarity 枚举定义
- **Story 003**: CardSystem 模板注册表（Instance 通过 template_id 查询模板）
- **Story 004**: CardSystem.create_instance() 工厂 + GSM.allocate_card_id() 集成
- **Story 005**: serialize_instance / deserialize_instance 序列化

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: CardInstance extends RefCounted，声明 class_name CardInstance
  - Given: `src/card_system/card_instance.gd` 存在
  - When: `var inst: CardInstance = CardInstance.new()`
  - Then: `assert_true(inst is RefCounted)`；`assert_true(inst is CardInstance)`
  - Edge cases: 确认 `class_name` 唯一，无与 CardTemplate 冲突

- **AC-002**: card_instance_id: int 字段（默认 0，由 GSM 分配）
  - Given: 新建 `var inst := CardInstance.new()`
  - When: 读取 `inst.card_instance_id`
  - Then: `assert_eq(inst.card_instance_id, 0)`；`assert_eq(typeof(inst.card_instance_id), TYPE_INT)`
  - Edge cases: 确认字段可写（`inst.card_instance_id = 42` 后读取 == 42）

- **AC-003**: template_id: StringName 字段（指向 CardTemplate.card_id）
  - Given: 新建 CardInstance
  - When: `inst.template_id = &"card_test_001"`
  - Then: `assert_eq(typeof(inst.template_id), TYPE_STRING_NAME)`；`assert_eq(inst.template_id, &"card_test_001")`
  - Edge cases: 默认值 `&""` 表示未关联模板

- **AC-004**: 成长状态字段（level: int 默认 1, inscriptions: Array[Dictionary], breakthrough_layers: int 默认 0）
  - Given: 新建 CardInstance
  - When: 读取各字段
  - Then: `assert_eq(inst.level, 1)`；`assert_eq(typeof(inst.level), TYPE_INT)`；`assert_eq(inst.inscriptions, [])`；`assert_eq(inst.breakthrough_layers, 0)`；`assert_eq(typeof(inst.breakthrough_layers), TYPE_INT)`
  - Edge cases: inscriptions 默认空数组且为强类型 Array[Dictionary]；inscriptions 数组独立性（`a.inscriptions.append(x)` 不影响 b.inscriptions）

- **AC-005**: 绑定字段 binding_target_id: StringName
  - Given: 新建 CardInstance
  - When: `inst.binding_target_id = &"char_001"`
  - Then: `assert_eq(typeof(inst.binding_target_id), TYPE_STRING_NAME)`；`assert_eq(inst.binding_target_id, &"char_001")`
  - Edge cases: 默认值 `&""` 表示未绑定

- **AC-006**: 获得来源字段（acquired_chapter: int, acquired_event_id: StringName, acquired_method: int）
  - Given: 新建 CardInstance
  - When: 读取各字段
  - Then: 三字段类型分别为 TYPE_INT、TYPE_STRING_NAME、TYPE_INT；默认值 chapter=0、event_id=&""、method=AcquiredMethod.DROP
  - Edge cases: acquired_method 默认值验证 `assert_eq(inst.acquired_method, AcquiredMethod.DROP)`

- **AC-007**: 两张同名卡 CardInstance 实例的 level 独立
  - Given: `var a := CardInstance.new()`、`var b := CardInstance.new()`，二者 template_id 相同（&"card_same"），初始 level 均为 1
  - When: `a.level = 5`
  - Then: `assert_eq(a.level, 5)`；`assert_eq(b.level, 1)`（b 未受影响）
  - Edge cases: 同步修改 `b.level = 10` 后再读 `a.level` 仍为 5；inscriptions 数组独立性（`a.inscriptions.append({"id": 1})` 不影响 b.inscriptions）

- **AC-008**: AcquiredMethod 枚举定义（DROP/SHOP/EVENT/CRAFT/TRIBULATION）
  - Given: `src/card_system/acquired_method.gd` 存在
  - When: 读取 AcquiredMethod 枚举常量
  - Then: 断言 5 个常量存在且名称精确匹配：DROP / SHOP / EVENT / CRAFT / TRIBULATION
  - Edge cases: 断言枚举值总数 == 5；确认枚举宿主路径 `AcquiredMethod.DROP`（独立 class_name）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_system/test_card_instance.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（CardType/Rarity 枚举虽不在 CardInstance 中直接引用，但同 Epic 上下文）
- Unlocks: Story 004（create_instance 创建 CardInstance）、Story 005（serialize_instance 序列化 CardInstance 字段）
