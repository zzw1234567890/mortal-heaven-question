# Story 001: ResourceSystem Autoload + LingCaiQuality 枚举 + GSM 第二层扩展 + 读写 API

> **Epic**: resource-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration（需集成测试）
> **Estimate**: 3.5h
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-08

## Context

**GDD**: `design/gdd/resource-system.md`
**Requirement**: `TR-resource-001`（待 `/architecture-review` 注册——当前 tr-registry.yaml 无 resource 条目，不阻塞实现）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0019（资源系统——Core 层 Autoload 公式服务 + GSM 数据存储分离）
**ADR Decision Summary**: ResourceSystem 作为 Core 层 Autoload #16，持有 LingCaiQuality 枚举 + 类型安全的读写 API（add/spend/can_spend/get），不持有资源数据——所有数据存储在 GSM `player.resources` 域。资源变更通过 GSM Cat 1 `batch_updated` 传播，ResourceSystem 不发射自有数据信号。

**Engine**: Godot 4.6.3 | **Risk**: LOW（Dictionary、Signal、Autoload 均为 4.0+ 稳定 API）
**Engine Notes**: 无截止后 API。

**Control Manifest Rules (Core 层 + Foundation 层)**:
- **Required**: 所有资源写入必须通过 `ResourceSystem.add_resource()` / `ResourceSystem.spend_resource()` —— 来源: ADR-0019
- **Required**: 资源数据存储在 GSM `player.resources.*` —— ResourceSystem 是纯逻辑层
- **Required**: Foundation Autoload 测试用动态分派模式（控制清单 2026-08-05 新增规则——适用 Core Autoload）
- **Forbidden**: 绝不直接写 `GSM.player.resources.*` —— 始终通过 ResourceSystem API
- **Forbidden**: 绝不在消费者系统中重新定义资源公式 —— 真理来源在 ResourceSystem（Story 002）
- **Forbidden**: ResourceSystem 是 Autoload —— 绝不声明 `class_name`（控制清单 2026-08-05 新增规则）

---

## Acceptance Criteria

*From ADR-0019 §验证标准 + GDD §验收标准 §核心接口:*

- [ ] **AC-001**: ResourceSystem extends Node（Autoload #16），不声明 `class_name`
- [ ] **AC-002**: `enum LingCaiQuality { LOW = 1, MEDIUM = 2, HIGH = 3, TOP = 4 }` 枚举定义
- [ ] **AC-003**: `add_resource(type: StringName, amount: int, quality: int = -1) -> bool` 方法签名
- [ ] **AC-004**: `add_resource(&"ling_shi", 25)` 当 ling_shi=10 时 → ling_shi 变为 35，返回 true
- [ ] **AC-005**: `add_resource(&"ling_cai", 3, LingCaiQuality.LOW)` → 低级灵材 +3，返回 true
- [ ] **AC-006**: `add_resource(&"ling_cai", 1, 5)` 无效品质 → 返回 false
- [ ] **AC-007**: `spend_resource(type: StringName, amount: int, quality: int = -1) -> bool` 方法签名
- [ ] **AC-008**: `spend_resource(&"ling_shi", 30)` 当 ling_shi=50 时 → 返回 true，ling_shi 变为 20
- [ ] **AC-009**: `spend_resource(&"ling_shi", 30)` 当 ling_shi=20 时 → 返回 false，ling_shi 仍为 20（余额不足不扣减）
- [ ] **AC-010**: `spend_resource(&"ling_cai", 2, LingCaiQuality.LOW)` 当 low=5 时 → 返回 true，low 变为 3
- [ ] **AC-011**: `spend_resource(&"ling_cai", 5, LingCaiQuality.LOW)` 当 low=3 时 → 返回 false，low 仍为 3
- [ ] **AC-012**: `can_spend(type: StringName, amount: int, quality: int = -1) -> bool` 余额校验——所有消费操作前置入口
- [ ] **AC-013**: `get_resource(type: StringName, quality: int = -1) -> int` 查询方法
- [ ] **AC-014**: `get_resource(&"ling_cai")` 不传 quality → 返回所有品质总和（low+medium+high+top）
- [ ] **AC-015**: 资源变更通过 GSM `batch_updated` Cat 1 信号传播（ResourceSystem 不发射自有数据信号）
- [ ] **AC-016**: GSM 第二层新增 `_set_resource_ling_shi(value: int) -> void` 原子写入方法（跨 Epic 修改，已批准——见下方 §跨 Epic 修改声明）
- [ ] **AC-017**: GSM 第二层新增 `_set_resource_ling_cai(quality: int, value: int) -> void` 原子写入方法（跨 Epic 修改，已批准）
- [ ] **AC-018**: `_set_resource_ling_shi` 内部 `max(0, value)` 非负守卫——即便绕过 ResourceSystem 也防止负数
- [ ] **AC-018b**: `_set_resource_ling_cai` 内部 `max(0, value)` 非负守卫——ling_cai 各品质同样防止负数（AC-018 对称覆盖）
- [ ] **AC-019**: ResourceSystem 不发射自有 `resource_changed` 信号——`resource_changed` 是 GSM Cat 1 域信号（ADR-0001），由 GSM `_emit_domain_signal` 在帧末统一发射，ResourceSystem 仅通过 GSM 第二层方法间接触发它（ADR-0007 §决策矩阵"数据变更→Cat 1 GSM 信号"，ADR-0019 §信号传播路径）
- [ ] **AC-020**: `spend_resource(&"ling_shi", 30)` 成功后，GSM 的 `resource_changed` Cat 1 域信号被触发，载荷 `(type=&"ling_shi", delta=-30, balance=20)`——正向覆盖 GDD AC-20
- [ ] **AC-021**: `add_resource`/`spend_resource` 的 `amount < 0` → 返回 false 且不修改 GSM 状态（防 spend(-10) 变相增加资源——非负 amount 守卫）

### 跨 Epic 修改声明（AC-016/017）

**修改目标**: `src/foundation/game_state_manager.gd`（Foundation 层 GSM，Sprint 1 已实现）

**新增方法**:
- `_set_resource_ling_shi(value: int) -> void` —— 写入 `player.resources.ling_shi` + `_buffer_change` + 帧末 `batch_updated`
- `_set_resource_ling_cai(quality: int, value: int) -> void` —— 写入 `player.resources.ling_cai[{low,medium,high,top}]` + `_buffer_change` + 帧末 `batch_updated`

**理由**: ADR-0019 §GSM 第二层扩展方法明确要求 ResourceSystem 通过这两个专用方法操作资源数据，遵循 ADR-0008（CombatSystem 定义 `_set_battle_*`）和 ADR-0014（ExplorationSystem 定义 `set_exploration_*`）的先例。这是 Core→Foundation 的合理委托——GSM 作为数据容器提供原子写入接口，ResourceSystem 作为逻辑层负责余额校验和类型安全包装。

**模式**: 同 card-system Story 004 的 GSM 4 方法补齐——跨 Epic 修改经用户批准扩大本 Story 范围。

---

## Implementation Notes

*Derived from ADR-0019 §关键接口 + §GSM 第二层扩展方法:*

1. **文件位置**:
   - `src/core/resource_system.gd`（Core 层，Autoload #16）
   - `src/foundation/game_state_manager.gd`（Foundation 层，新增 2 个第二层方法——跨 Epic 修改）
2. **类声明**: `extends Node`（不声明 class_name——Autoload 固有权衡）
3. **LingCaiQuality 枚举**（ADR-0019 §关键接口）:
   ```gdscript
   enum LingCaiQuality { LOW = 1, MEDIUM = 2, HIGH = 3, TOP = 4 }
   ```
4. **add_resource 实现**（ADR-0019 §关键接口 + AC-021 非负 amount 守卫）:
   ```gdscript
   func add_resource(type: StringName, amount: int, quality: int = -1) -> bool:
       if amount < 0:
           push_error("ResourceSystem.add_resource: amount 不能为负数（%d）" % amount)
           return false
       match type:
           &"ling_shi":
               var new_val: int = GSM.player.resources.ling_shi + amount
               GSM._set_resource_ling_shi(new_val)
               return true
           &"ling_cai":
               if quality < 1 or quality > 4:
                   return false
               var key: String = _quality_key(quality)
               var current: int = GSM.player.resources.ling_cai[key]
               GSM._set_resource_ling_cai(quality, current + amount)
               return true
       return false
   ```
5. **spend_resource 实现**（ADR-0019 §关键接口 + AC-021 非负 amount 守卫）:
   ```gdscript
   func spend_resource(type: StringName, amount: int, quality: int = -1) -> bool:
       if amount < 0:
           push_error("ResourceSystem.spend_resource: amount 不能为负数（%d）" % amount)
           return false
       if not can_spend(type, amount, quality):
           return false
       match type:
           &"ling_shi":
               GSM._set_resource_ling_shi(GSM.player.resources.ling_shi - amount)
               return true
           &"ling_cai":
               var current: int = _get_ling_cai_by_quality(quality)
               GSM._set_resource_ling_cai(quality, current - amount)
               return true
       return false
   ```
6. **can_spend 实现**（ADR-0019 §关键接口）:
   ```gdscript
   func can_spend(type: StringName, amount: int, quality: int = -1) -> bool:
       return get_resource(type, quality) >= amount
   ```
7. **get_resource 实现**（ADR-0019 §关键接口）:
   ```gdscript
   func get_resource(type: StringName, quality: int = -1) -> int:
       match type:
           &"ling_shi":
               return GSM.player.resources.ling_shi
           &"ling_cai":
               if quality >= 1:
                   return _get_ling_cai_by_quality(quality)
               return GSM.player.resources.ling_cai.low + GSM.player.resources.ling_cai.medium + \
                      GSM.player.resources.ling_cai.high + GSM.player.resources.ling_cai.top
       return 0
   ```
8. **_quality_key 辅助方法**:
   ```gdscript
   func _quality_key(quality: int) -> String:
       match quality:
           1: return "low"
           2: return "medium"
           3: return "high"
           4: return "top"
       return "low"
   ```
9. **GSM 第二层方法实现**（跨 Epic 修改，遵循既有 `_buffer_change` 模式）:
   ```gdscript
   # 在 game_state_manager.gd 中新增
   func _set_resource_ling_shi(value: int) -> void:
       value = maxi(0, value)  # 非负守卫
       var old_val: int = player.resources.ling_shi
       if old_val == value:
           return
       player.resources.ling_shi = value
       _buffer_change("player.resources.ling_shi", old_val, value)

   func _set_resource_ling_cai(quality: int, value: int) -> void:
       value = maxi(0, value)  # 非负守卫
       var key: String = ["low", "medium", "high", "top"][quality - 1]
       var old_val: int = player.resources.ling_cai[key]
       if old_val == value:
           return
       player.resources.ling_cai[key] = value
       _buffer_change("player.resources.ling_cai.%s" % key, old_val, value)
   ```
10. **信号传播路径**（ADR-0019 §资源变更契约）:
    - `ResourceSystem.spend_resource()` → `GSM._set_resource_ling_shi(new_val)` → `_buffer_change` → 帧末 `batch_updated({"player.resources.ling_shi": {old, new}})` → HUD 刷新
    - ResourceSystem 自身不发射任何 Cat 2b 信号——资源变更是数据变更，天然属于 GSM Cat 1 职责
11. **测试模式**: 测试用 `var rs: Node = RS_SCRIPT.new()` 动态分派 + 真实 GSM Autoload（before_each/after_each 清理 GSM 状态，同 test_apply_outcomes.gd 模式）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: 资源公式纯函数（dismantle_value / delete_card_cost / realm_gap_penalty 等 6 个公式）
- **HUD 灵石/灵材显示**: UI Epic 职责
- **商店购买逻辑**: ExplorationSystem Epic 职责（调用 spend_resource）
- **拆解流程触发**: DeckEditingSystem Epic 职责（调用 add_resource）
- **炼丹灵材消耗**: AlchemySystem Epic 职责（调用 spend_resource）
- **身份天赋初始灵石**: IdentitySelectionSystem Epic 职责（开局调用 add_resource）

---

## QA Test Cases

*Derived from ADR-0019 §验证标准 + GDD §验收标准 §核心接口:*

- **AC-001**: ResourceSystem extends Node，不声明 class_name
  - Given: `src/core/resource_system.gd` 存在
  - When: `var script := load("res://src/core/resource_system.gd")`
  - Then: `assert_eq(script.get_instance_base_type(), "Node")`；源码无 `class_name` 关键字
  - Edge cases: 测试用 `var rs: Node = RS_SCRIPT.new()` 动态分派

- **AC-002**: LingCaiQuality 枚举定义
  - Given: ResourceSystem 脚本已加载
  - When: 读取 LingCaiQuality 枚举常量
  - Then: 断言 4 个常量存在且名称精确匹配：LOW=1、MEDIUM=2、HIGH=3、TOP=4
  - Edge cases: 断言枚举值总数 == 4

- **AC-003**: add_resource 方法签名
  - Given: `var rs: Node = RS_SCRIPT.new()`；GSM Autoload 可用
  - When: `var ok: bool = rs.add_resource(&"ling_shi", 25)`
  - Then: `assert_eq(typeof(ok), TYPE_BOOL)`
  - Edge cases: quality 参数默认 -1（ling_shi 不需要）

- **AC-004**: add_resource(&"ling_shi", 25) 当 ling_shi=10 → ling_shi=35
  - Given: rs 已创建；GSM.player.resources.ling_shi = 10（测试前设置）
  - When: `rs.add_resource(&"ling_shi", 25)`
  - Then: `assert_true(ok)`；`assert_eq(GSM.player.resources.ling_shi, 35)`
  - Edge cases: GDD AC-1 直接引用

- **AC-005**: add_resource(&"ling_cai", 3, LOW) → 低级灵材 +3
  - Given: rs 已创建；GSM.player.resources.ling_cai.low = 0
  - When: `rs.add_resource(&"ling_cai", 3, ResourceSystem.LingCaiQuality.LOW)`
  - Then: `assert_true(ok)`；`assert_eq(GSM.player.resources.ling_cai.low, 3)`
  - Edge cases: 其他品质不受影响

- **AC-006**: add_resource(&"ling_cai", 1, 5) 无效品质 → false
  - Given: rs 已创建
  - When: `rs.add_resource(&"ling_cai", 1, 5)`
  - Then: `assert_false(ok)`
  - Edge cases: quality=0、quality=-1、quality=99 同处理

- **AC-007**: spend_resource 方法签名
  - Given: rs 已创建
  - When: `var ok: bool = rs.spend_resource(&"ling_shi", 30)`
  - Then: `assert_eq(typeof(ok), TYPE_BOOL)`
  - Edge cases: 返回 false 表示余额不足

- **AC-008**: spend_resource(&"ling_shi", 30) 当 ling_shi=50 → true, ling_shi=20
  - Given: rs 已创建；GSM.player.resources.ling_shi = 50
  - When: `rs.spend_resource(&"ling_shi", 30)`
  - Then: `assert_true(ok)`；`assert_eq(GSM.player.resources.ling_shi, 20)`
  - Edge cases: GDD AC-2 / ADR-0019 §验证标准直接引用

- **AC-009**: spend_resource(&"ling_shi", 30) 当 ling_shi=20 → false, ling_shi 仍=20
  - Given: rs 已创建；GSM.player.resources.ling_shi = 20
  - When: `rs.spend_resource(&"ling_shi", 30)`
  - Then: `assert_false(ok)`；`assert_eq(GSM.player.resources.ling_shi, 20)`（未变）
  - Edge cases: GDD AC-3 / ADR-0019 §验证标准直接引用——余额不足不扣减

- **AC-010**: spend_resource(&"ling_cai", 2, LOW) 当 low=5 → true, low=3
  - Given: rs 已创建；GSM.player.resources.ling_cai.low = 5
  - When: `rs.spend_resource(&"ling_cai", 2, ResourceSystem.LingCaiQuality.LOW)`
  - Then: `assert_true(ok)`；`assert_eq(GSM.player.resources.ling_cai.low, 3)`
  - Edge cases: GDD AC-4 直接引用

- **AC-011**: spend_resource(&"ling_cai", 5, LOW) 当 low=3 → false, low 仍=3
  - Given: rs 已创建；GSM.player.resources.ling_cai.low = 3
  - When: `rs.spend_resource(&"ling_cai", 5, ResourceSystem.LingCaiQuality.LOW)`
  - Then: `assert_false(ok)`；`assert_eq(GSM.player.resources.ling_cai.low, 3)`（未变）
  - Edge cases: GDD AC-5 直接引用

- **AC-012**: can_spend 余额校验
  - Given: rs 已创建；GSM.player.resources.ling_shi = 50
  - When: `rs.can_spend(&"ling_shi", 30)`
  - Then: `assert_true(ok)`（50 >= 30）
  - Edge cases: can_spend(&"ling_shi", 60) → false（50 < 60）

- **AC-013**: get_resource 查询方法
  - Given: rs 已创建；GSM.player.resources.ling_shi = 100
  - When: `var val: int = rs.get_resource(&"ling_shi")`
  - Then: `assert_eq(val, 100)`
  - Edge cases: 灵材查询带 quality 参数

- **AC-014**: get_resource(&"ling_cai") 不传 quality → 所有品质总和
  - Given: rs 已创建；ling_cai.low=2, medium=3, high=1, top=0
  - When: `rs.get_resource(&"ling_cai")`
  - Then: `assert_eq(result, 6)`（2+3+1+0）
  - Edge cases: 传 quality 参数返回单品质数量

- **AC-015**: 资源变更通过 GSM batch_updated Cat 1 信号传播
  - Given: rs 已创建；GSM.player.resources.ling_shi = 50；`var batch_emitted := false`；`GSM.batch_updated.connect(func(c): batch_emitted = true)`
  - When: `rs.spend_resource(&"ling_shi", 30)`；推进一帧（等待帧末 flush）
  - Then: `assert_true(batch_emitted)`；batch_updated 载荷含 `player.resources.ling_shi` 路径
  - Edge cases: ResourceSystem 不发射自有信号——grep `signal` 在 resource_system.gd 中无 resource_changed

- **AC-016**: GSM 第二层新增 _set_resource_ling_shi
  - Given: GSM Autoload 已注册（Sprint 1 完成）
  - When: `GSM._set_resource_ling_shi(200)`
  - Then: `assert_eq(GSM.player.resources.ling_shi, 200)`；`assert_true(GSM.has_method("_set_resource_ling_shi"))`
  - Edge cases: 跨 Epic 修改——GSM 第二层方法新增

- **AC-017**: GSM 第二层新增 _set_resource_ling_cai
  - Given: GSM Autoload 已注册
  - When: `GSM._set_resource_ling_cai(1, 10)`
  - Then: `assert_eq(GSM.player.resources.ling_cai.low, 10)`；`assert_true(GSM.has_method("_set_resource_ling_cai"))`
  - Edge cases: quality=2/3/4 分别写入 medium/high/top

- **AC-018**: _set_resource_ling_shi 非负守卫
  - Given: GSM Autoload 已注册
  - When: `GSM._set_resource_ling_shi(-50)`（尝试写入负数）
  - Then: `assert_eq(GSM.player.resources.ling_shi, 0)`（max(0, -50) = 0，非负守卫生效）
  - Edge cases: ADR-0019 §风险——即便绕过 ResourceSystem，GSM 层面防止负数

- **AC-018b**: _set_resource_ling_cai 非负守卫（AC-018 对称覆盖）
  - Given: GSM Autoload 已注册
  - When: `GSM._set_resource_ling_cai(1, -50)`（尝试写入负数灵材）
  - Then: `assert_eq(GSM.player.resources.ling_cai.low, 0)`（max(0, -50) = 0，非负守卫生效）
  - Edge cases: quality=2/3/4 同处理

- **AC-019**: ResourceSystem 不发射自有 resource_changed 信号
  - Given: ResourceSystem 脚本已加载
  - When: 读取 `rs.get_signal_list()`
  - Then: 无 `resource_changed` 信号——该信号是 GSM Cat 1 域信号（ADR-0001），由 GSM `_emit_domain_signal` 帧末统一发射；ResourceSystem 仅通过 GSM 第二层方法间接触发它
  - Edge cases: 代码审查检查点——grep `signal` 在 resource_system.gd 中无数据变更信号

- **AC-020**: GSM resource_changed 域信号正向触发
  - Given: rs 已创建；GSM.player.resources.ling_shi = 50；连接 GSM.realm_changed... `var received := []`；`GameStateManager.resource_changed.connect(func(t, d, b): received.append([t, d, b]))`
  - When: `rs.spend_resource(&"ling_shi", 30)`；`await get_tree().process_frame`（帧末 _emit_domain_signal 发射）
  - Then: `assert_eq(received.size(), 1)`；`assert_eq(received[0][0], &"ling_shi")`；`assert_eq(received[0][1], -30)`；`assert_eq(received[0][2], 20)`——正向覆盖 GDD AC-20
  - Edge cases: GDD AC-21 灵材变体同触发

- **AC-021**: 负数 amount 拒绝
  - Given: rs 已创建；GSM.player.resources.ling_shi = 50
  - When: `rs.spend_resource(&"ling_shi", -10)`（尝试负数消费）
  - Then: `assert_false(ok)`；`assert_eq(GSM.player.resources.ling_shi, 50)`（未变——防变相增加资源）
  - Edge cases: `add_resource(&"ling_shi", -25)` 同返回 false 不修改；amount=0 允许（无操作返回 true）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/resource_system/test_resource_read_write_api.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Sprint 1 GSM（player.resources 域 + _buffer_change + batch_updated 已实现）；本 Story 跨 Epic 新增 GSM 2 个第二层方法
- Unlocks: Story 002（同文件扩展公式方法）、所有消费 ResourceSystem 的 Epic（DeckEditingSystem、AlchemySystem、ExplorationSystem、CombatSystem 等）

---

## Completion Notes

**Completed**：2026-08-08
**Criteria**：22/22 通过（AC-001..AC-021 + AC-018b，含 code-review 新增 AC-020/021 + 补充无效 type/dan_yao_sui_pian/余额不足不发射信号/quality 越界守卫测试）

**Deviations**（全部 ADVISORY，已修复）：
- **HIGH-1**（已修复）GSM `_set_resource_ling_cai` 缺 quality 范围守卫——quality=0 负索引静默写入 "top"。修复为入口 `if quality < 1 or quality > 4: push_error + return`。
- **HIGH-2**（已修复）EventSystem `_check_resource_condition` 未适配 ling_cai 嵌套字典——`resources.get("ling_cai")` 返回 Dictionary 赋给 int 触发类型错误。修复为 Dictionary 分支求四品质总和。
- **HIGH-3**（已修复）ResourceSystem `spend_resource` ling_cai 分支缺显式 quality 检查（与 add_resource 不对称）。修复为补 `if quality < 1 or quality > 4: push_error + return false`。
- **LOW-2**（已修复）`resource_changed` 信号文档补充 ling_cai balance 语义（单品质余额 vs 总和）。
- **LOW-3**（已修复）AC-015 与 AC-020 统一刷新方式——改用直接同步 `_flush_pending_changes()` 替代 await process_frame。
- **LOW-4**（已修复）`after_each` 改为仅断开本套件创建的信号连接（`_track_gsm_signal` + `_signal_callables` 追踪），避免清除其他套件持久连接。
- **MEDIUM**（已修复）旧存档向前兼容——`_migrate_resources_dict` 已实现，补 `test_deserialize_migrates_legacy_flat_ling_cai` 测试验证旧扁平 int 格式迁移为四品质零值字典。
- **设计决策**（用户批准）ling_cai 重构为嵌套字典 {low,medium,high,top}；删除 GSM 旧 add/spend_resource（ADR-0019 禁止后门）；EventSystem ADD_RESOURCE 改用 resource_add_requested Cat 2c 信号委托；负数 amount 拒绝（AC-021）。
- **遗留待办**（非阻塞）GDD §5 `add_resource → void` 需同步修订为 `→ bool`；ADR-0019 第 265 行对 ADR-0007 #11 的错误引用需 design-doc 修订。

**Test Evidence**：Integration — `tests/integration/resource_system/test_resource_read_write_api.gd`（40 测试覆盖 22 条 AC）+ `tests/unit/gsm/serialize_deserialize_test.gd`（旧存档迁移测试）+ `tests/unit/gsm/atomic_write_methods_test.gd`（迁移为 GSM 第二层方法测试）+ `tests/unit/event_system/test_apply_outcomes.gd` + `tests/integration/event_system/test_full_event_flow.gd`（ling_cai 嵌套字典适配 + resource_add_requested 信号连接）
**Code Review**：已完成——gdscript-specialist CHANGES REQUIRED→修复 3 HIGH + 5 LOW 后 lead-programmer APPROVED + qa-tester PASS（22/22 AC COVERED）

**测试结果**：全量套件 723/722 通过（1 pending 是与本 Story 无关的 save_load 多步迁移占位），2626 断言
