# Story 001: EffectTemplate/EffectInstance 双层对象模型（4 种子类）

> **Epic**: 卡牌效果解析引擎 (Card Effect Engine)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-16

## Completion Notes
**Completed**：2026-08-16
**Criteria**：4/4 通过（AC-001~004 全部由单元测试覆盖）
**Deviations**：C1 已解决——`EffectFactory.create_instance(template: EffectTemplate, source_card_instance_id) → EffectBase` 经 technical-director 裁决为「两层 API 分离」正解，ADR-0009 §双层对象模型（第 99 行）、§需求（第 57 行）、§对象生命周期（第 309-313 行）已回写同步
**Test Evidence**：`tests/unit/card_effect_engine/test_template_instance_model.gd`（29 测试 / 71 断言全通过）；全量套件 63 scripts / 1175 tests / 1174 passing / 1 pending / 0 failing 零回归
**Code Review**：已完成（lead-programmer CONCERNS→已解决 C1；qa-lead GAPS→已补齐 5 测试）
**ADR 变更**：`docs/decisions/ADR-0009-card-effect-engine-resource-refcounted-model.md` 回写工厂接口签名（消除 57/99 行内部矛盾 + EffectInstance→EffectBase 命名漂移）

## Context

**GDD**: `design/gdd/card-effect-engine.md`
**Requirement**: `TR-effect-001`（4 种效果类型——即时/持续/触发式/替代——覆盖 222 张卡牌）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0009（卡牌效果引擎——Resource 模板 + RefCounted 运行时实例 + 栈式结算）
**ADR Decision Summary**: CardEffectEngine 采用双层对象模型——`EffectTemplate`（Resource 子类，`.tres`，`@export` 字段，Inspector 可编辑的只读模板）+ `EffectInstance`（RefCounted 子类层级，运行时轻量级实例）。运行时实例由 `EffectFactory` 从 Resource 创建，不持有 Resource 引用。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: 依赖截止后 API——Godot 4.5 `@abstract`（效果基类 `EffectBase` 强制子类实现 `_resolve()`）、类型化 `Array[EffectInstance]`（4.4+ 泛型数组）。需 GUT 测试验证 `@abstract` 应用于 `extends RefCounted` 类时是否阻止 `.new()`（4.5 新特性，提交效果层级前必须先验证）。

**Control Manifest Rules (Feature 层)**:
- **Required**: EffectTemplate（Resource, `.tres`）只读 —— EffectInstance（RefCounted）运行时层
- **Required**: 效果生命周期信号归类为 Cat 2b，通过 `_emit_signal_safe` 路由
- **Forbidden**: 绝不让 CardEffectEngine 直接写 GSM —— 所有效果通过子系统接口执行
- **Forbidden**: 绝不复制 `OutcomeType` 枚举 —— 扩展 ADR-0003 的权威枚举（新增 `APPLY_STATUS`/`MODIFY_STAT`/`TRIGGER_CHAIN`/`ACTIVATE_FORMATION`/`MODIFY_COST`）

---

## Acceptance Criteria

*From GDD `design/gdd/card-effect-engine.md` §验收标准 → 基础效果结算，scoped to this story:*

- [x] **AC-001**: GIVEN 玩家打出伤害型符箓（base_value=3），AND 目标无任何伤害修正效果，AND 无本命绑定，WHEN 确认目标并结算，THEN 目标HP减少3点（精确匹配 effective_value）
- [x] **AC-002**: GIVEN 玩家打出伤害型符箓（base_value=3），AND 角色有本命绑定（binding_multiplier=1.5），WHEN 结算，THEN 目标HP减少 `floor(3×1.5)=4` 点
- [x] **AC-003**: GIVEN 玩家打出功法卡"铁布衫——绑定角色攻击+2"并选择己方角色A，WHEN 结算完成，THEN 角色A的ATK属性值增加2点（通过 `get_accumulated_value(target, "ATK")` 验证）
- [x] **AC-004**: GIVEN 角色有本命加成条件满足，WHEN 绑定对应功法/法宝，THEN `binding_multiplier` 锁定为 1.5（在绑定时预计算）且 UI 中效果数值旁显示"×1.5"标识

---

## Implementation Notes

*Derived from ADR-0009 §决策 → 双层对象模型:*

1. **文件位置**: `src/feature/card_effect_engine/` 下新建 `effect_template.gd`（`class_name EffectTemplate extends Resource`）、`effect_base.gd`（`class_name EffectBase extends RefCounted`，声明 `@abstract`）、`effect_instance.gd` 系列（4 个子类）。
2. **EffectTemplate（Resource）**: `@export` 字段——`template_id: StringName`、`type: EffectType`（枚举）、`base_value: int`、`target_selector`、`conditions: Array`、`animation_id: StringName`、`description_tmpl: String`。策划在 Inspector 中编辑，存储在 `assets/cards/effects/`。运行时只读——绝不写模板字段。
3. **EffectBase（RefCounted，`@abstract`）**: 声明 `_resolve()` 虚函数，强制 4 子类实现。运行时最小字段集——`template_id: StringName`、`base_value: int`、`target_spec`、`conditions: Array`、`source_card_instance_id: int`、`activation_sequence: int`、`priority: int`（次级决胜）。**不持有 Resource 引用**（避免共享引用污染，与 ADR-0006 Template/Instance 分离模式一致）。
4. **4 个 RefCounted 子类**:
   - `InstantEffect` — 立即结算（伤害/治疗/抽牌/弃牌/费用修改/移除状态/临时属性）
   - `PersistentEffect` — 持续生效（功法/法宝/阵法/buff/debuff；含 `duration`、`stacking_rule`、`max_stacks`、`cooldown`、`binding_multiplier`）
   - `TriggeredEffect` — 条件触发（回合开始/攻击/击杀/延迟触发；含 `trigger_event`、`delay_turns`、`trigger_once`、`max_triggers_per_turn`）
   - `ReplacementEffect` — 拦截修改（替代阵亡/效果增幅/效果无效化；含 `replacement_priority`）
5. **EffectFactory**: `create_instance(template_id, source_card_instance_id) → EffectInstance`——从 Resource 读取字段生成轻量级 RefCounted 实例。工厂是 Template 与 Instance 之间的唯一桥梁。
6. **OutcomeType 扩展**: 扩展 ADR-0003 的权威枚举（非复制）——新增 `APPLY_STATUS`、`MODIFY_STAT`、`TRIGGER_CHAIN`、`ACTIVATE_FORMATION`、`MODIFY_COST`。
7. **5 个 Cat 2b 信号**: `effect_registered` / `effect_removed` / `effect_suspended` / `effect_restored` / `stack_overflow_warning`——声明在 CardEffectEngine Autoload，通过 `_emit_signal_safe` 路由（本 Story 仅声明，发射细节在 002/003 实现）。
8. **有效值计算**: `effective_value = floor(base_value × binding_multiplier)`——`floor()` 向下取整（3 × 1.5 = 4.5 → 4）。`binding_multiplier` 由 BindingSystem 在绑定时预计算锁定（1.0 或 1.5），效果引擎查询 `get_binding_multiplier(card_instance_id)` 而非运行时重算。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: ResolutionStack 栈式结算引擎——优先级队列排序 + LIFO 出栈 + 中分辨率插入（本 Story 只定义对象，不实现结算调度）
- **Story 003**: 触发链硬限制 10 层 + `visited_card_ids` 循环检测（本 Story 不实现深度计数与截断）
- **Story 004**: PRD 伪随机分布引擎（本 Story 不实现概率效果）
- **Story 005**: AI 干跑评估接口 `GameStateSnapshot`（本 Story 不实现快照与评估 API）
- **叠加/堆叠规则**: 同名叠加 stack_count、stack_limit、不同角色独立叠加——binding-system（ADR-0013）职责
- **目标选择规则**: TargetSpec 的详细选择与决胜逻辑——后续目标选择 story / deployment-system 职责

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: 伤害效果精确匹配 effective_value
  - Given: 玩家打出伤害符箓 base_value=3，目标无伤害修正效果，无本命绑定
  - When: 确认目标并结算
  - Then: 目标 HP 减少 3 点（等于 effective_value）
  - Edge cases: base_value=0 时 HP 不减少（严格非负）；无目标可选中时效果不结算

- **AC-002**: 本命绑定 ×1.5 floor 取整
  - Given: 伤害符箓 base_value=3，binding_multiplier=1.5
  - When: 结算
  - Then: 目标 HP 减少 floor(3×1.5)=4 点（而非 4.5）
  - Edge cases: 偶数 base_value=4 → floor(4×1.5)=6（整数）；奇数 base_value=3 → floor=4（损失 0.5）

- **AC-003**: 功法绑定 ATK+2 通过 get_accumulated_value 验证
  - Given: 玩家打出功法卡"铁布衫——绑定角色攻击+2"并选择己方角色 A
  - When: 结算完成
  - Then: `get_accumulated_value(A, "ATK")` 返回值增加 2
  - Edge cases: 绑定前查询返回基础值；解绑后加成移除

- **AC-004**: binding_multiplier 锁定 1.5 + UI 标识
  - Given: 角色本命加成条件满足
  - When: 绑定对应功法/法宝
  - Then: `binding_multiplier` 在绑定时预计算锁定为 1.5，UI 效果数值旁显示"×1.5"标识
  - Edge cases: 非本命绑定锁定为 1.0；第二绑定尝试自动降级为普通绑定（1.0）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_effect_engine/test_template_instance_model.gd` — must exist and pass
**Status**: [x] Created and passing（29 测试函数 / 71 断言，全通过）

---

## Dependencies

- Depends on: None（CardSystem 模板查询 `get_template(id)` 已就绪——软依赖；BindingSystem `get_binding_multiplier` 软依赖——本 Story 可用注入的 mock 验证）
- Unlocks: Story 002（ResolutionStack 依赖 EffectInstance 对象模型）；Story 004（PRD 依赖 EffectInstance 字段）
