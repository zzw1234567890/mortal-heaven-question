# Story 001: StatusTemplate/Instance 双层模型 + 8 阶段管线核心

> **Epic**: status-effect
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 1d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-10

## Context

**GDD**: `design/gdd/status-system.md`
**Requirement**: `TR-status-001`（状态效果生命周期——8 阶段管线）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0011（状态效果系统——双层对象模型 + Autoload 服务 + 专用 Cat 2b 信号总线）
**ADR Decision Summary**: StatusEffectSystem 作为 Core 层 Autoload #8，采用双层模型——StatusTemplate（Resource, .tres）+ StatusInstance（RefCounted）。运行时实例存储在内部 `_instances`/`_by_target` 注册表（非 GSM）。CombatSystem 通过 `tick_all()` 在 Phase 0 编排倒计时，CardEffectEngine 通过 `apply_status()`/`remove_status()` 施加/移除。

**Engine**: Godot 4.6 | **Risk**: LOW（Dictionary + 信号 + RefCounted + Autoload——4.x 成熟 API）
**Engine Notes**: 不依赖 4.4+ 新特性。RefCounted 即时引用计数（非 GC），50+ 实例/战斗无抖动。

**Control Manifest Rules (Core 层)**:
- **Required**: StatusEffectSystem 是 Autoload —— 绝不声明 `class_name`（同 RealmSystem/FactionSystem/CardSystem/CostSystem 模式）
- **Required**: 双层模型——StatusTemplate 只读（Resource 共享引用语义），运行时可变状态在 StatusInstance
- **Required**: Foundation Autoload 测试用动态分派模式（`SES_SCRIPT.new()` + `var ses: Node`）
- **Forbidden**: 活跃状态不存储在 GSM battle.temp_effects（内部注册表——GSM 仅战斗结束接收快照）
- **Forbidden**: 模板内容运行时写入（const Dictionary 团队约定只读）

---

## Acceptance Criteria

*From ADR-0011 §验证标准 + GDD status-system.md §验收标准:*

- [ ] **AC-001**: StatusEffectSystem extends Node，不声明 `class_name`
- [ ] **AC-002**: StatusTemplate Resource 类——@export 字段：template_id、type、stack_rule、max_stacks、base_duration、base_value、icon_path、description_tmpl、default_priority、metadata
- [ ] **AC-003**: StatusInstance RefCounted 类——运行时字段：id、template_id、target_id、duration、applied_turn、value、base_value、current_stacks、source_card_instance_id、priority、is_hidden、is_expired、metadata
- [ ] **AC-004**: `_instances: Dictionary[int, StatusInstance]`（key=status_id）+ `_by_target: Dictionary[int, Array[int]]`（key=target_id）内部注册表
- [ ] **AC-005**: `apply_status(target_id, template_id, source_card_instance_id, overrides={})` 返回 ApplyResult（applied/status_id/reason）
- [ ] **AC-006**: 目标无状态时施加 `template_id="poison_3"`（duration=3, stack_rule=刷新）→ 获得状态，current_stacks=1，duration=3，reason="new"
- [ ] **AC-007**: `get_active_statuses(target_id)` 返回该角色所有活跃 status_id 列表
- [ ] **AC-008**: `has_status(target_id, template_id)` 检查是否存在指定模板的状态
- [ ] **AC-009**: `remove_status(status_id)` 移除指定状态实例，返回 bool；不存在返回 false（不报错）
- [ ] **AC-010**: `tick_all(field_characters)` 倒计时——duration>0 的状态 -1，duration==0 标记 is_expired
- [ ] **AC-011**: 永久状态（duration=-1）不参与倒计时——`tick_all` 后保持 -1
- [ ] **AC-012**: 同回合新施加的状态不在当回合倒计时（下一己方回合 Phase 0 才减）
- [ ] **AC-013**: `tick_all` 的 duration 递减不发射 `status_updated`（递减非用户可见事件）
- [ ] **AC-014**: 过期状态在 Phase 0 结算后统一移除（延迟移除——确保"回合开始触发"效果仍能看到 duration=1 的状态）
- [ ] **AC-015**: 4 个 Cat 2b 信号声明：`status_applied`、`status_removed`、`status_updated`、`status_immunity_blocked`
- [ ] **AC-016**: `apply_status` 成功后发射 `status_applied`（载荷含 target_id/status_id/template_id/stacks/reason）
- [ ] **AC-017**: `remove_status` 成功后发射 `status_removed`（载荷含 target_id/status_id/template_id/reason）
- [ ] **AC-018**: `get_status_template(template_id)` 只读访问器封装 `_templates` 注册表

---

## Implementation Notes

*Derived from ADR-0011 §双层对象模型 §运行时存储架构 §状态施加管线 §持续时间倒计时:*

1. **文件位置**: `src/core/status_effect/status_effect_system.gd`（Core 层，Autoload #8——在 CostSystem #7 之后、CombatSystem #9 之前）+ `src/core/status_effect/status_template.gd` + `src/core/status_effect/status_instance.gd`
2. **StatusTemplate**: `class_name StatusTemplate extends Resource`，@export 10 字段（同 CardTemplate 模式）
3. **StatusInstance**: `class_name StatusInstance extends RefCounted`，普通 var 声明 13 字段（无 @export——纯运行时）
4. **StatusEffectSystem**: `extends Node`（不声明 class_name），持有 `_instances`/`_by_target`/`_templates`/`_suspended`/`_immunity_flags`/`_next_status_id`
5. **apply_status 管线**: 加载模板 → 溢出预检查 → 免疫检查 → 同名查找 → 叠加判定 → 注册实例 → 发射信号（Story 002 实现叠加/免疫/溢出细节，本 Story 实现基础 NEW 路径）
6. **_register_instance/_remove_instance**: 集中管理 `_instances` + `_by_target` 同步更新（避免一致性 bug）
7. **tick_all**: 遍历 field_characters → `_by_target` 查询 → duration-1 + is_expired 标记；第二遍 `remove_expired_statuses` 统一移除并发射 `status_removed`
8. **_ready**: 加载 `res://assets/statuses/` 目录的 .tres 模板到 `_templates`（同 CardSystem 加载模式）；若目录不存在则空注册表（测试用）
9. **测试模式**: `SES_SCRIPT.new()` 构造实例，`var ses: Node` 持有 + 动态分派，返回值显式类型注解

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: 3 叠加规则（独立/刷新/叠加上限）+ 免疫多级检查 + 20 上限驱逐
- **Story 003**: snapshot 导出 GSM + 暂挂/恢复排序 + 与 BindingManager 排序契约
- **CombatSystem Phase 0 集成**: `tick_all()` 由 CombatSystem 调用 ——战斗 Epic（ADR-0008）职责
- **CardEffectEngine 集成**: `apply_status()`/`remove_status()` 调用 ——卡牌效果 Epic（ADR-0009）职责
- **CombatUI 头顶图标**: 订阅 Cat 2b 信号 ——战斗 UI Epic 职责

---

## QA Test Cases

*From QA 计划 qa-plan-sprint-3-2026-08-10.md §Story 3-4 + ADR-0011 §验证标准:*

- **AC-001**: extends Node + 不声明 class_name
  - Given: StatusEffectSystem 脚本已加载
  - When: `SES_SCRIPT.get_instance_base_type()` / `get_global_name()`
  - Then: base type == "Node" + global_name == &""
  - Edge cases: 动态分派 `var ses: Node = SES_SCRIPT.new()`

- **AC-002**: StatusTemplate @export 字段完整
  - Given: StatusTemplate 脚本已加载
  - When: 检查 @export 字段列表
  - Then: 含 template_id/type/stack_rule/max_stacks/base_duration/base_value/icon_path/description_tmpl/default_priority/metadata 10 字段
  - Edge cases: type 为 StatusType 枚举，stack_rule 为 StackRule 枚举

- **AC-003**: StatusInstance 运行时字段完整
  - Given: StatusInstance 脚本已加载
  - When: 检查 var 字段
  - Then: 含 id/template_id/target_id/duration/applied_turn/value/base_value/current_stacks/source_card_instance_id/priority/is_hidden/is_expired/metadata 13 字段
  - Edge cases: 无 @export（纯运行时 RefCounted）

- **AC-004**: 内部注册表初始化
  - Given: `ses = SES_SCRIPT.new()`
  - When: 检查 `_instances` 和 `_by_target`
  - Then: 均为空 Dictionary
  - Edge cases: `_next_status_id` 初始为 1

- **AC-005**: apply_status 返回 ApplyResult
  - Given: ses 已创建 + 模板已注入
  - When: `ses.apply_status(target_id, &"poison_3", source_id)`
  - Then: 返回 Dictionary 含 applied(bool)/status_id(int)/reason(String)
  - Edge cases: reason ∈ {"new", "refreshed", "stacked", "immune", "max_stacks", "unknown_template"}

- **AC-006**: 新状态施加（NEW 路径）
  - Given: 目标无任何状态 + 模板 poison_3（duration=3, stack_rule=刷新）
  - When: `ses.apply_status(target_id, &"poison_3", source_id)`
  - Then: applied=true + current_stacks=1 + duration=3 + reason="new"
  - Edge cases: status_id 全局唯一递增

- **AC-007**: get_active_statuses 返回 status_id 列表
  - Given: 目标有 3 个活跃状态
  - When: `ses.get_active_statuses(target_id)`
  - Then: 返回含 3 个 status_id 的 Array[int]
  - Edge cases: 无状态返回空数组

- **AC-008**: has_status 查询
  - Given: 目标有 poison_3 状态
  - When: `ses.has_status(target_id, &"poison_3")` / `ses.has_status(target_id, &"freeze_1")`
  - Then: true / false
  - Edge cases: 过期状态（is_expired=true）仍返回 true 直到移除

- **AC-009**: remove_status
  - Given: 目标有状态 status_id=5
  - When: `ses.remove_status(5)` / `ses.remove_status(999)`
  - Then: true（移除成功 + 发射 status_removed）/ false（不存在，不报错）
  - Edge cases: 移除后 get_active_statuses 不再含该 id

- **AC-010**: tick_all 倒计时
  - Given: 目标有 duration=3 的状态
  - When: `ses.tick_all([character])` 一次
  - Then: duration 变为 2
  - Edge cases: 3 次 tick 后 duration=0 + is_expired=true

- **AC-011**: 永久状态不倒计时
  - Given: 目标有 duration=-1 的永久状态
  - When: `ses.tick_all([character])`
  - Then: duration 保持 -1，is_expired 保持 false
  - Edge cases: tick_all 后状态仍在 get_active_statuses 中

- **AC-012**: 同回合施加不立即倒计时
  - Given: Phase 0 施加 duration=3 的状态
  - When: 同回合 `tick_all`
  - Then: 新施加状态 duration 不减（下一己方回合才减）
  - Edge cases: applied_turn 字段用于判定

- **AC-013**: 倒计时不发射 status_updated
  - Given: 监听 `status_updated` 信号
  - When: `ses.tick_all([character])`（仅 duration 递减）
  - Then: `status_updated` 不发射
  - Edge cases: 仅 remove_expired 发射 status_removed

- **AC-014**: 过期状态延迟移除
  - Given: 目标有 duration=1 的状态
  - When: `ses.tick_all([character])`（duration→0, is_expired=true）→ 结算后 remove_expired
  - Then: 状态在 tick_all 返回后被移除 + 发射 status_removed（reason="expired"）
  - Edge cases: 延迟移除确保"回合开始触发"效果能看到 duration=1 状态

- **AC-015**: 4 个 Cat 2b 信号声明
  - Given: StatusEffectSystem 脚本已加载
  - When: `SES_SCRIPT.get_script_signal_list()`
  - Then: 含 status_applied/status_removed/status_updated/status_immunity_blocked
  - Edge cases: 信号声明在 StatusEffectSystem 而非 GSM

- **AC-016**: apply_status 成功发射 status_applied
  - Given: 监听 `status_applied`
  - When: `ses.apply_status(target_id, &"poison_3", source_id)` 成功
  - Then: 发射 status_applied，载荷 {target_id, status_id, template_id, stacks, reason}
  - Edge cases: reason="new"

- **AC-017**: remove_status 发射 status_removed
  - Given: 监听 `status_removed`
  - When: `ses.remove_status(status_id)` 成功
  - Then: 发射 status_removed，载荷 {target_id, status_id, template_id, reason}
  - Edge cases: reason="manual"/"expired"/"overflow"

- **AC-018**: get_status_template 只读访问器
  - Given: 模板已注入 `_templates`
  - When: `ses.get_status_template(&"poison_3")`
  - Then: 返回 StatusTemplate 对象
  - Edge cases: 未知 template_id 返回 null

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/status_effect/test_status_lifecycle.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 无（GSM 只读查询已就绪；CardSystem 软依赖——source_card_instance_id 引用完整性校验可选）
- Unlocks: Story 002（叠加规则/免疫/溢出——依赖 001 的 apply_status 管线 + 注册表）；Story 003（snapshot/暂挂——依赖 001 的注册表）
