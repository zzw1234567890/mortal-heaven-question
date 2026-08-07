# Story 004: CardSystem 实例工厂 + GSM 集成

> **Epic**: card-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration（需集成测试）
> **Estimate**: 3.5h
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-06

## Context

**GDD**: `design/gdd/card-system.md`
**Requirement**: `TR-card-001` + `TR-card-002`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0006（卡牌数据模型——Template/Instance 分离 + Resource 序列化）
**ADR Decision Summary**: CardSystem 作为实例工厂通过 `create_instance(template_id)` 创建 CardInstance 并调用 `GSM.allocate_card_id()` 分配全局唯一 ID。模板加载完成后调用 `GSM.enable_validation(db)` 启用卡牌校验。

**Engine**: Godot 4.6.3 | **Risk**: HIGH（训练截止后 API）
**Engine Notes**: Autoload 顺序保证 GSM #1 先于 CardSystem #6 就绪；`create_instance` 调用 GSM 方法时 GSM 必然已完成 `_ready()`。

**Control Manifest Rules (Core 层 + Foundation 层)**:
- **Required**: CardSystem 是模板注册表 + 实例工厂 —— `create_instance(template_id)` 分配 GSM ID
- **Required**: GSM 存储序列化的 Dictionary（模型 A）—— 通过 `GSM.add_card_to_collection(dict)` 写入
- **Required**: 启动时校验跳过模式 —— CardSystem 模板加载完成后调用 `GSM.enable_validation(db)`
- **Required**: Foundation Autoload 测试用动态分派模式（控制清单 2026-08-05 新增规则）
- **Forbidden**: Foundation 层原则 #3 —— Foundation 层系统不得依赖 Core/Feature 层系统（Core→Foundation 调用方向正确）

---

## Acceptance Criteria

*From ADR-0006 §CardSystem Autoload + §GSM 集成合约 + §启动合约:*

- [ ] **AC-001**: `create_instance(template_id: StringName) -> CardInstance` 方法签名
- [ ] **AC-002**: `create_instance` 调用 `GSM.allocate_card_id()` 分配全局唯一 ID——通过观察返回的 `card_instance_id` 唯一非零间接验证
- [ ] **AC-003**: `create_instance` 设置 `inst.template_id = template_id` + `inst.acquired_chapter = GSM.narrative.current_chapter`
- [ ] **AC-004**: `create_instance` 对未知 template_id → `push_error` + return null（统一为 push_error 而非 assert，保证 release 模式可测试）
- [ ] **AC-005**: `enable_validation` 调用前，`GSM.add_card_to_collection(inst_dict)` 拒绝写入（`validation_enabled = false`，GSM 已在 Sprint 1 实现此行为）
- [ ] **AC-006**: 模板加载完成后，CardSystem **主动调用** `GSM.enable_validation(self.templates)`（Core→Foundation 依赖方向正确，符合 Foundation 原则 #3）—— **见下方架构偏差声明**
- [ ] **AC-007**: `enable_validation` 后，`GSM.add_card_to_collection(inst_dict)` 对有效 template_id 成功
- [ ] **AC-008**: `enable_validation` 后，`GSM.add_card_to_collection(inst_dict)` 对无效 template_id 拒绝 + `push_error`（GSM 已在 Sprint 1 实现校验逻辑）
- [ ] **AC-009**: `CardSystem._ready()` 断言 `GSM != null`（Autoload 顺序保证——间接验证：cs 能调用 GSM 方法不崩溃）
- [ ] **AC-010**: GSM 已在 Foundation 层实现 `allocate_card_id` / `add_card_to_collection` / `remove_card_from_collection` / `enable_validation`（Sprint 1 完成，本 Story 仅调用——回归守护）
- [ ] **AC-011**: `enable_validation` 前 `create_instance` 允许创建实例（实例不入库，仅返回对象）——预加载状态行为明确

### 架构偏差声明（AC-006）

**ADR-0006 §启动合约原文**："GSM 收到 templates_loaded 信号后调用 GSM.enable_validation(db=CardSystem.templates)"——即 GSM 监听 CardSystem 信号。

**本 Story 实现**：CardSystem 模板加载完成后**主动调用** `GSM.enable_validation(self.templates)`。

**偏差理由**：
- ADR-0006 原方案要求 GSM（Foundation 层）监听 CardSystem（Core 层）的 `templates_loaded` 信号，这违反 **Foundation 原则 #3**（Foundation 层系统不得依赖 Core/Feature 层系统）。
- 改为 CardSystem 主动调用 GSM 符合 **Core→Foundation 依赖方向**，与 CardSystem 调用 `GSM.allocate_card_id()` / `GSM.add_card_to_collection()` 的现有模式一致。
- 这是对 ADR-0006 启动合约的合理细化，建议后续通过 `/architecture-decision` 修订 ADR-0006 §启动合约以同步此决策。

---

## Implementation Notes

*Derived from ADR-0006 §CardSystem Autoload + §GSM 集成合约:*

1. **文件位置**: `src/core/card_system/card_system.gd`（同 Story 003，扩展实例工厂方法）
2. **create_instance 实现**（ADR-0006 §CardSystem 公共 API）:
   ```gdscript
   func create_instance(template_id: StringName) -> CardInstance:
       var tmpl: CardTemplate = get_template(template_id)
       if tmpl == null:
           push_error("CardSystem.create_instance: 未知 template_id '%s'" % template_id)
           return null
       var inst := CardInstance.new()
       inst.card_instance_id = GSM.allocate_card_id()
       inst.template_id = template_id
       inst.acquired_chapter = GSM.narrative.current_chapter
       return inst
   ```
3. **enable_validation 主动调用**（AC-006 偏差实现）:
   ```gdscript
   # 在 _process 中检测全部加载完成后：
   func _on_all_templates_loaded() -> void:
       set_process(false)
       GSM.enable_validation(self.templates)
       templates_loaded.emit(templates.size())
   ```
4. **GSM API 调用**（已由 Sprint 1 实现，本 Story 仅调用）:
   - `GSM.allocate_card_id() -> int` —— 单调递增 ID
   - `GSM.add_card_to_collection(inst_dict: Dictionary) -> bool` —— 校验开启前返回 false
   - `GSM.enable_validation(db: Dictionary)` —— 启用卡牌校验
   - `GSM.remove_card_from_collection(card_instance_id: int) -> bool`
5. **测试模式**: 测试用 `var cs: Node = CS_SCRIPT.new()` 动态分派 + 真实 GSM Autoload（before_each/after_each 清理 GSM 状态，同 test_apply_outcomes.gd 模式）
6. **create_instance 不入库**: `create_instance` 仅创建并返回 CardInstance 对象，不调用 `GSM.add_card_to_collection`——入库由调用方（EventSystem ADD_CARD 委托、战利品系统等）显式执行。AC-011 明确此行为。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: CardTemplate Resource 定义
- **Story 002**: CardInstance RefCounted 定义
- **Story 003**: CardSystem 模板注册表 + 异步加载（templates 字段 + get_template）
- **Story 005**: serialize_instance / deserialize_instance 序列化
- **战利品系统/事件系统 ADD_CARD 委托**: 调用 create_instance + serialize_instance + add_card_to_collection 的完整流程属各自 Epic

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: create_instance(template_id: StringName) -> CardInstance
  - Given: `var cs: Node = CS_SCRIPT.new()`；cs.templates 已含 &"card_test" 模板；GSM Autoload 可用
  - When: `var inst: CardInstance = cs.create_instance(&"card_test")`
  - Then: `assert_true(inst is CardInstance)`；`assert_not_null(inst)`
  - Edge cases: 返回值非 null

- **AC-002**: create_instance 调用 GSM.allocate_card_id() 分配全局唯一 ID
  - Given: cs.templates 含 &"card_test"
  - When: 连续调用 `cs.create_instance(&"card_test")` 两次得到 inst1、inst2
  - Then: `assert_true(inst1.card_instance_id != 0)`；`assert_true(inst2.card_instance_id != 0)`；`assert_true(inst1.card_instance_id != inst2.card_instance_id)`
  - Edge cases: ID 单调递增（inst2 > inst1）

- **AC-003**: create_instance 设置 inst.template_id + acquired_chapter
  - Given: cs.templates 含 &"card_test"；GSM.narrative.current_chapter == 3（测试前设置）
  - When: `var inst := cs.create_instance(&"card_test")`
  - Then: `assert_eq(inst.template_id, &"card_test")`；`assert_eq(inst.acquired_chapter, 3)`
  - Edge cases: current_chapter == 0（初始状态）→ acquired_chapter == 0

- **AC-004**: create_instance 对未知 template_id → push_error + return null
  - Given: cs.templates 不含 &"card_unknown"
  - When: `var inst := cs.create_instance(&"card_unknown")`
  - Then: `assert_null(inst)`；`assert_push_error_count(1)`
  - Edge cases: 空字符串 template_id(&"") → 同未知处理

- **AC-005**: enable_validation 调用前，GSM.add_card_to_collection 拒绝写入
  - Given: 新建 cs，未调用 enable_validation；构造 inst_dict
  - When: `var ok: bool = GSM.add_card_to_collection(inst_dict)`
  - Then: `assert_false(ok)`（拒绝）；`assert_false(GSM.validation_enabled)`
  - Edge cases: 确认 GSM 集合未增加；确认返回 false 而非崩溃

- **AC-006**: 模板加载完成后，CardSystem 主动调用 GSM.enable_validation(self.templates)
  - Given: cs.templates 已加载完成（模拟 _on_all_templates_loaded）
  - When: 调用 `cs._on_all_templates_loaded()`（或推进到加载完成）
  - Then: `assert_true(GSM.validation_enabled)`
  - Edge cases: 重复调用 _on_all_templates_loaded → enable_validation 幂等（GSM 已实现幂等保护，Sprint 1）

- **AC-007**: enable_validation 后，add_card_to_collection 对有效 template_id 成功
  - Given: GSM 已 enable_validation(db=cs.templates)；cs.templates 含 &"card_test"
  - When: `var inst := cs.create_instance(&"card_test")`；`var dict := cs.serialize_instance(inst)`（Story 005）；`var ok := GSM.add_card_to_collection(dict)`
  - Then: `assert_true(ok)`；GSM.collection.owned_cards 含该 dict（按 card_instance_id 查找）
  - Edge cases: **依赖 Story 005 的 serialize_instance**——若 Story 005 未实现，测试可手工构造 dict

- **AC-008**: enable_validation 后，add_card_to_collection 对无效 template_id 拒绝 + push_error
  - Given: GSM 已 enable_validation；构造 dict，其 template_id = &"card_invalid"（不在 db 中）
  - When: `GSM.add_card_to_collection(dict)`
  - Then: `assert_false(ok)`；`assert_push_error_count(1)`
  - Edge cases: inst.template_id == &"" → 同无效处理

- **AC-009**: CardSystem._ready() 断言 GSM != null（Autoload 顺序保证）
  - Given: GSM Autoload 已注册（Sprint 1 完成）
  - When: `cs._ready()`（或 cs 调用 GSM 方法）
  - Then: 无崩溃；间接验证 cs 能调用 `GSM.allocate_card_id()` 返回非零值
  - Edge cases: 测试环境 GSM 必然存在（Autoload），单测无需模拟缺失

- **AC-010**: GSM 已在 Foundation 层实现（本 Story 仅调用，回归守护）
  - Given: GSM Autoload 存在
  - When: 反射检查 GSM 方法存在性
  - Then: `assert_true(GSM.has_method("allocate_card_id"))`；`assert_true(GSM.has_method("add_card_to_collection"))`；`assert_true(GSM.has_method("remove_card_from_collection"))`；`assert_true(GSM.has_method("enable_validation"))`
  - Edge cases: 此为前置依赖验证，非本 Story 实现内容

- **AC-011**: enable_validation 前 create_instance 允许创建实例（不入库）
  - Given: 新建 cs，未调用 enable_validation；cs.templates 含 &"card_test"
  - When: `var inst := cs.create_instance(&"card_test")`
  - Then: `assert_not_null(inst)`；`assert_true(inst is CardInstance)`；inst.card_instance_id 已分配（非零）
  - Edge cases: 实例对象有效，但调用 GSM.add_card_to_collection 会被拒绝（AC-005）——实例创建与入库解耦

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/card_system/test_card_system_factory.gd` — must exist and pass
**Status**: [x] Created and passing (21 tests, 134 assertions)

---

## Completion Notes

**Completed**：2026-08-06
**Criteria**：11/11 通过（所有 AC 自动化验证通过）

**Deviations**（全部 ADVISORY，已在 code-review 后修复或记录）：
- **HIGH-1**：`_next_card_instance_id` 未持久化——已修复。GSM.deserialize 后调 `_recover_card_id_counter()` 从 `collection.owned_cards` 恢复最大 ID（兼容 card_instance_id / instance_id 两种字段命名），避免读档后新建实例 ID 冲突
- **HIGH-2**：`add_card_to_collection` 信号载荷用 `"id"` 而非 `"card_instance_id"`——已修复。统一为 `inst_dict.get("card_instance_id", inst_dict.get("instance_id", 0))`，与 remove_card_from_collection 一致
- **AC-006 偏差**：CardSystem 主动调 `enable_validation` 而非 GSM 监听 templates_loaded 信号——符合 Core→Foundation 依赖方向（Foundation 原则 #3）。故事已声明，建议后续修订 ADR-0006 §启动合约同步
- **AC-003 章节类型冲突**：方案 A——`CHAPTER_NUMBER_MAP` 常量映射（chapter_1→1...chapter_5→5），`_resolve_chapter_number` 解析 String→int。空/未知章节→0。GDD 定义 acquired_chapter 为 int，GSM 存 String，需此映射桥接
- **GSM 新增 allocate_card_id**：Story 004 前置依赖修复——原假设 Sprint 1 已实现 `GSM.allocate_card_id()`，实际未实现。方案 A：在 GSM 添加该方法 + `_next_card_instance_id` 计数器（初始 1，单调递增，0 保留为"未分配"哨兵）
- **LOW-1**：DirAccess 失败路径统一走 `_on_all_templates_loaded()`——已修复。两条失败路径（空目录 + DirAccess 失败）行为一致
- **MEDIUM**：`_on_all_templates_loaded` 幂等性测试——已补 2 测试（validation 幂等 + 信号每次发射）
- **MEDIUM**：create_instance 不入库语义验证——已补 1 测试（enable_validation 后调用，collection 仍为空，区分"未调用 add" vs "调用了但被拒绝"）
- **LOW**：CHAPTER_NUMBER_MAP 边界值——已补 1 测试（chapter_1..chapter_5 全覆盖）

**Test Evidence**：Integration — `tests/integration/card_system/test_card_system_factory.gd`（21 测试函数，134 断言，全部通过）
**Code Review**：已完成——godot-gdscript-specialist CHANGES REQUIRED（2 HIGH 已修复）+ qa-tester PASS（缺口已补）。2 项 HIGH 已修复，4 项 MEDIUM/LOW 缺口测试已补，1 项 ADR-0006 §启动合约偏差建议后续修订。

### 测试结果

- **card_system 工厂测试 21/21 通过**，134 断言，零失败
- **全量套件 599/600 通过**（1 个 risky 为 fixture 加载警告，非本 Story 引入）
- 覆盖 11 条 AC 全部 + 4 项边界情况补充

### 关键修正记录

1. **GSM.allocate_card_id 新增**——_next_card_instance_id 计数器（初始 1，单调递增）
2. **_recover_card_id_counter**——deserialize 后从 owned_cards 恢复最大 ID，避免读档后 ID 冲突
3. **add_card_to_collection 信号载荷修正**——card_instance_id 替代 id，与 remove 一致
4. **_on_all_templates_loaded 重构**——先 enable_validation 后 emit templates_loaded，统一 DirAccess 失败 + 空目录 + 正常完成三条路径
5. **CHAPTER_NUMBER_MAP**——章节 String→int 映射桥接 GDD int 与 GSM String
6. **AC-006 偏差**——CardSystem 主动调 enable_validation，符合 Core→Foundation 方向

---

## Dependencies

- Depends on: Story 001（CardTemplate）、Story 002（CardInstance）、Story 003（templates 注册表 + get_template）、Sprint 1 GSM（allocate_card_id / add_card_to_collection / enable_validation 已实现）
- Unlocks: Story 005（serialize_instance 配合 create_instance + add_card_to_collection 完成完整流程）
