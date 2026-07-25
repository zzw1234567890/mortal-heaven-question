# ADR-0011：状态效果系统 — 双层对象模型 + Autoload 服务 + 专用 Cat 2b 信号总线

## 状态
Proposed

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Core / Status Effect |
| **知识风险** | LOW（Dictionary 操作、信号系统、Autoload 模式、RefCounted 实例管理均为 4.x 成熟 API。不依赖 4.4+ 新特性） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/deprecated-apis.md`、`docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **使用的截止后 API** | None——核心逻辑不依赖 4.4+ 新增 API。`Dictionary` 键查找、`signal` 发射、`RefCounted` 子类均为 4.0+ 稳定 API |
| **需要验证** | `RefCounted` 子类在 300+ 实例/战斗下的 GC 抖动（Godot 4.5 优化了引用计数性能——需在目标硬件上验证 60fps 表现）；GDScript `const Dictionary` 嵌套内容非真正不可变——需 GUT 冒烟测试验证 StatusTemplate 注册表完整性；`Array[StatusInstance].filter()` 在 `get_statuses_by_type()` 中的性能（最多 20 元素/角色） |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`player.*` / `battle.*` 只读查询；不直接写入 GSM——状态数据存储在 StatusEffectSystem 内部注册表，GSM 仅在战斗结束时接收序列化快照）；ADR-0007（三分类信号体系——`status_applied/removed/updated/immunity_blocked` 分类为 Cat 2b 系统信号；CombatSystem 直接调用 StatusEffectSystem 方法而非订阅信号）；ADR-0008（CombatSystem——Phase 0 发动 `tick_all()` 倒计时编排；Phase 4/5 发动 `apply_status()` / `remove_status()` 作为效果结算的一部分；`battle_end()` 发动 `clear_all_statuses()` 清理）；ADR-0009（CardEffectEngine——效果引擎通过 `apply_status()` / `remove_status()` / `get_active_statuses()` / `get_accumulated_value()` 接口调用 StatusEffectSystem；不直接访问 StatusEffectSystem 内部状态） |
| **启用** | ADR-0012（战斗 UI 系统——订阅 StatusEffectSystem 的 Cat 2b 信号更新角色头顶状态图标和 tooltip）；ADR-0014（AI 系统——通过 `get_active_statuses()` / `get_accumulated_value()` 查询目标状态以评估技能价值）；ADR-0015（绑定系统——角色阵亡时调用 `suspend_statuses_by_source()` / 复活时调用 `restore_statuses()` 协调非绑定来源的状态暂挂/恢复） |
| **阻塞** | 状态效果 Epic（所有 buff/debuff/特殊状态的施加、叠加、倒计时、免疫、移除——依赖 StatusEffectSystem 运行时）；战斗 Epic（Phase 0 状态倒计时 + Phase 4/5 状态施加结算）；卡牌效果 Epic（效果引擎的 APPLY_STATUS / REMOVE_STATUS / MODIFY_STAT 效果类型依赖 StatusEffectSystem 接口） |
| **排序说明** | Core 层——在 Foundation 层全部 7 个 ADR 被接受后编写。与 ADR-0009（CardEffectEngine）并行——两者互为消费者/提供者。Autoload 初始化顺序：StatusEffectSystem 为 Autoload #8（完整链：GSM #1 / InputManager #2 / SceneManager #3 / SaveLoad #4 / EventSystem #5 / CardSystem #6 / CostSystem #7 / StatusEffectSystem #8 / CombatSystem #9 / CardEffectEngine #10 / RealmSystem #11——ADR-0009 §对象生命周期 + ADR-0010 §Autoload 初始化）。StatusEffectSystem 的 `_ready()` 执行时，#1-#7 已完全初始化 |

## 上下文

### 问题陈述

`status-system.md` GDD 定义了完整的状态效果生命周期——8 个阶段的施加/合并/跟踪/倒计时/触发/暂挂/恢复/移除管线、3 种叠加规则（独立/刷新/叠加上限）、免疫多级检查链（类型→模板→属性）、属性累计修正计算、20 个活跃状态上限的溢出驱逐策略。但 GDD 关注的是"状态应该表现出什么行为"，本 ADR 需要解决的是"状态系统如何在 Godot 4.6 中工程化实现"：

1. **对象模型选择**（GDD 开放问题 #1）：StatusEffect 数据结构在 Godot 中的表示方式——双层 Resource+RefCounted 模型 vs 纯 RefCounted 类层级 vs 纯 Dictionary 动态类型
2. **运行时存储位置**：活跃状态实例存储在 StatusEffectSystem Autoload 内部 vs GSM `battle.temp_effects` 域。GDD §依赖关系说"状态数据存储在 GSM 的 battle.temp_effects 域"，但 §7 信号广播又说"状态系统维护自己的信号总线"——存在内部矛盾需要解决
3. **信号路由策略**（GDD §7 vs §依赖关系冲突）：GDD §7 建议专用 Cat 2b 信号总线（status_applied/removed/updated/immunity_blocked），但 §依赖关系又说"状态变更通过 GSM 信号广播"。两个段落指向相反的架构方向
4. **max_stacks 来源**（GDD 开放问题 #2）：叠加层数上限由 StatusTemplate 数据表定义 vs 由效果引擎在调用 `apply_status()` 时作为参数传入
5. **与 GSM 的边界**：StatusEffectSystem 是直接读写 GSM 还是维护独立的内部状态？属性修正（`get_accumulated_value()`）通过 GSM Cat 1 传播还是通过 StatusEffectSystem 自有查询接口？

`architecture.md` 将 StatusEffectSystem 归入 CORE 层——被 CombatSystem、CardEffectEngine、AI、CombatUI、HUD、BindingSystem 6 个系统消费。

### 约束

- **Core 层定位**：StatusEffectSystem 是 Core 层 Autoload——消费 Foundation 层（GSM 只读查询），被 Feature 层（CombatSystem、CardEffectEngine）和 Presentation 层（CombatUI、HUD）消费。不依赖 Feature 层系统
- **双层对象模型**：StatusTemplate（Resource，`.tres`，策划在 Inspector 编辑）只读——所有运行时可变状态在 StatusInstance（RefCounted）上管理（与 ADR-0002 CardTemplate/CardInstance 和 ADR-0009 EffectTemplate/EffectInstance 分离模式一致）
- **状态生命周期**：创建→施加检查→施加/合并→持续跟踪→倒计时/触发→暂挂/恢复→到期移除——8 个阶段，每阶段有明确的触发条件和状态转换规则
- **叠加规则**：3 种——独立（每次创建新实例）、刷新（同名状态刷新 duration 取 max+value 取新值）、叠加上限（同名状态层数+1 直到 max_stacks，同时刷新 duration）
- **持续时间倒计时**：在每个己方回合 Phase 0（PREPARATION）执行——由 CombatSystem 编排（与 ADR-0008 Phase 0 一致）。永久状态（duration=-1）不参与倒计时
- **免疫多级检查**：类型免疫 → 模板免疫 → 属性免疫——短路求值，第一级通过即拒绝
- **溢出驱逐**：每角色最多 20 个活跃状态——超出时驱逐最旧非永久/非隐藏状态（按 applied_turn 升序 + id 字典序决胜）
- **暂挂/恢复**：角色阵亡→非绑定来源的状态暂挂（suspend），复活→恢复（restore）。绑定来源的状态由 BindingSystem 独立处理（永久移除，不可恢复——binding-system.md §7）
- **帧预算**：`tick_all()`（全场角色状态倒计时+过期移除）<1ms；`apply_status()` 单次调用 <0.05ms（含免疫检查+同名查找+叠加判定）；`get_accumulated_value()` 单次 <0.01ms（遍历最多 20 个活跃状态）
- **Autoload 计数**：StatusEffectSystem 为 Autoload #8——项目 Autoload 总数 11 个（完整链：GSM #1 / InputManager #2 / SceneManager #3 / SaveLoad #4 / EventSystem #5 / CardSystem #6 / CostSystem #7 / StatusEffectSystem #8 / CombatSystem #9 / CardEffectEngine #10 / RealmSystem #11——ADR-0009 §对象生命周期 + ADR-0010 §Autoload 初始化）

### 需求

- 双层对象模型：`StatusTemplate` Resource（`.tres`，@export 字段——template_id、type、stack_rule、max_stacks、base_duration、base_value、icon_path、description_tmpl、default_priority、metadata）+ `StatusInstance` RefCounted（运行时轻量级——id、template_id、target_id、duration、applied_turn、value、base_value、current_stacks、source_card_instance_id、priority、is_hidden、is_expired、metadata）
- StatusEffectSystem Autoload 内部运行时注册表：`_instances: Dictionary[int, StatusInstance]`（key=status_id）+ `_by_target: Dictionary[int, Array[int]]`（key=target_id → status_id 列表，快速查询某角色的所有状态）
- 6 个公共写入 API：`apply_status()`、`remove_status()`、`remove_statuses_by_source()`、`clear_all_statuses()`、`suspend_statuses_by_source()`、`restore_statuses()`
- 5 个公共查询 API：`get_active_statuses()`、`get_statuses_by_type()`、`has_status()`、`get_accumulated_value()`、`count_active_statuses()`
- 1 个编排 API：`tick_all(field_characters: Array)`——由 CombatSystem 在 Phase 0 调用
- 模板查询 API：`get_status_template(template_id: StringName) → StatusTemplate`——只读访问器，封装 `_templates` 注册表（与 ADR-0006 `CardSystem.get_template()` 模式一致），防止运行时意外修改 const Dictionary 内容
- 专用 Cat 2b 信号总线：`status_applied`、`status_removed`、`status_updated`、`status_immunity_blocked`（由 StatusEffectSystem Autoload 直接发射，通过 ADR-0007 `_emit_signal_safe` 包装器路由以追踪信号链深度）

## 决策

**StatusEffectSystem 实现为 Core 层 Autoload（StatusEffectSystem），采用双层对象模型——StatusTemplate（Resource, `.tres`, Inspector 可编辑）定义策划数据 + StatusInstance（RefCounted）管理运行时可变状态。运行时实例存储在 StatusEffectSystem 内部 Dictionary 注册表中，而非 GSM。专用 Cat 2b 信号总线（status_applied/removed/updated/immunity_blocked）通知 CombatUI/HUD——CombatSystem 通过直接方法调用编排 tick_all() 和施加/移除操作。属性修正通过 StatusEffectSystem 自有查询接口（get_accumulated_value()）提供，不通过 GSM 信号传播。**

### 双层对象模型

```
┌──────────────────────────────────────────────────────────────────┐
│                  StatusEffectSystem 对象模型                      │
│                                                                   │
│  ┌─────────────────────┐          ┌──────────────────────────┐  │
│  │  StatusTemplate     │  创建    │  StatusInstance (运行时)   │  │
│  │  (Resource, .tres)  │────────→ │  (RefCounted, 轻量级)    │  │
│  │                     │  工厂    │                          │  │
│  │  @export 字段：     │          │  id: int (全局唯一递增)   │  │
│  │  - template_id      │          │  template_id: StringName  │  │
│  │  - type: StatusType │          │  target_id: int           │  │
│  │  - stack_rule       │          │  duration: int (-1=永久)  │  │
│  │  - max_stacks       │          │  applied_turn: int        │  │
│  │  - base_duration    │          │  value: float             │  │
│  │  - base_value       │          │  base_value: float        │  │
│  │  - icon_path        │          │  current_stacks: int      │  │
│  │  - description_tmpl │          │  source_card_instance_id  │  │
│  │  - default_priority │          │  priority: int            │  │
│  │  - metadata         │          │  is_hidden: bool          │  │
│  └─────────────────────┘          │  is_expired: bool         │  │
│                                    │  metadata: Dictionary     │  │
│                                    └──────────────────────────┘  │
│                                                                   │
│  模板字段 = 策划在设计时配置（Inspector 可视化编辑）；              │
│  实例字段 = 运行时计算/追踪（不持久化到模板 Resource 中）          │
│                                                                   │
│  注意：StatusInstance 不需要 @export 或 Inspector 可见性——        │
│  它是纯运行时对象，使用普通 var 声明（与 ADR-0006 CardInstance     │
│  和 ADR-0009 EffectInstance 的 RefCounted 模式一致）               │
└──────────────────────────────────────────────────────────────────┘
```

**设计理由**：与 ADR-0002（CardTemplate/CardInstance）和 ADR-0009（EffectTemplate/EffectInstance）的 Template/Instance 分离模式一致——Godot Resource 的共享引用语义（修改一处污染所有引用者）决定了 Resource 必须只读。RefCounted 没有 Resource 的路径和引用语义包袱——更轻量（~200 bytes/实例），且天然防止模板污染。

**为什么不是纯 Dictionary**：类型安全——编译时检查 enum 值（StatusType.BUFF vs 字符串 "增益"）、`match` 分支遗漏在编译时捕获而非运行时调试。Godot Inspector 集成——策划可在编辑器中可视化编辑 `.tres` StatusTemplate，无需手写 JSON。220+ 状态模板 × 每战斗 50+ 实例的规模证明了编译时类型安全的价值。

### 运行时存储架构

```
StatusEffectSystem Autoload 内部状态：

  _instances: Dictionary[int, StatusInstance]
    # key = 全局唯一 status_id（单调递增 int）
    # 所有活跃状态实例的权威注册表——无论目标角色是谁

  _by_target: Dictionary[int, Array[int]]
    # key = target_id（角色实体 ID）
    # value = 该角色身上所有活跃状态的 status_id 列表
    # 用于 get_active_statuses(target_id) O(1) 角色级查询

  _templates: Dictionary[StringName, StatusTemplate]
    # key = template_id（如 "poison_3", "freeze_1"）
    # value = StatusTemplate Resource（只读——策划在 .tres 中编辑）
    # 由 _ready() 从 res://assets/statuses/ 同步加载
    # 封装为 get_status_template(template_id) → StatusTemplate 只读访问器
    # （与 ADR-0006 CardSystem.get_template() 一致）

  _suspended: Dictionary[int, Array[Dictionary]]
    # key = 阵亡角色 ID
    # value = 被暂挂状态的序列化快照列表（非绑定来源的状态）
    # 角色复活时通过 restore_statuses() 反序列化为新 StatusInstance
    # 角色永久死亡时清理——防止泄漏
```

**为什么不存储在 GSM.battle.temp_effects**：GDD §依赖关系称"状态数据存储在 GSM 的 battle.temp_effects 域"，但：
1. GSM 是键值存储——存储序列化 Dictionary，不持有 RefCounted 对象引用
2. StatusEffectSystem 需要 O(1) 的 `get_active_statuses(target_id)` 查询（每帧被 CombatUI 调用多次）——通过 `_by_target` 字典索引比遍历 GSM 字典快一个数量级
3. StatusEffectSystem 的叠加逻辑（同名查找、层数判定）需要实时访问完整 StatusInstance 对象图——序列化/反序列化开销不必要
4. GSM 仅在战斗结束时接收状态快照用于存档——StatusEffectSystem 通过 `serialize_all() → Array[Dictionary]` 导出，GSM 写入 `battle.temp_effects_snapshot`

**GDD §依赖关系更新**：原"状态数据存储在 GSM 的 battle.temp_effects 域"改为"活跃状态实例由 StatusEffectSystem Autoload 内部管理——GSM 仅在战斗结束时接收序列化快照用于存档"。

### 状态施加管线

```
apply_status(target_id: int, template_id: StringName, source_card_instance_id: int,
             overrides: Dictionary = {}) → ApplyResult:

  1. 加载模板
     template = get_status_template(template_id)  # 只读访问器——封装 _templates
     if template == null → 返回 {applied: false, reason: "unknown_template"}

  2. 溢出预检查
     if count_active_statuses(target_id) >= MAX_ACTIVE_STATUSES_PER_CHARACTER:
       eviction_candidate = _find_oldest_non_permanent_non_hidden(target_id)
       if eviction_candidate != null:
         _remove_instance(eviction_candidate, "overflow")
       else:
         返回 {applied: false, reason: "overflow_blocked"}

  3. 免疫检查
     if not can_apply(target_id, template):
       发射 status_immunity_blocked → Cat 2b（通过 _emit_signal_safe）
       返回 {applied: false, reason: "immune"}

  4. 同名查找
     existing = _find_by_template(target_id, template_id)

  5. 叠加判定
     if existing == null:
       → 创建新 StatusInstance → _register_instance()（同步更新 _instances + _by_target）
       → 发射 status_applied({reason: "new"})
       → 返回 {applied: true, status_id: new_id, reason: "new"}

     match existing.stack_rule:
       STACK_INDEPENDENT:
         → 创建新 StatusInstance（独立实例——与已存在同名状态并存）
         → 发射 status_applied({reason: "new_independent"})

       STACK_REFRESH:
         → existing.duration = max(existing.duration, template.base_duration)
         → existing.value = overrides.get("value", template.base_value)
         → 发射 status_updated({changes: {duration, value}})
         → 返回 {applied: true, status_id: existing.id, reason: "refreshed"}

       STACK_CUMULATIVE:
         if existing.current_stacks < existing.max_stacks:
           existing.current_stacks += 1
           existing.duration = max(existing.duration, template.base_duration)
           existing.value = template.base_value × existing.current_stacks
           发射 status_updated({changes: {stacks, value, duration}})
           返回 {applied: true, status_id: existing.id, reason: "stacked"}
         else:
           返回 {applied: false, status_id: existing.id, reason: "max_stacks"}
```

### 持续时间倒计时（Phase 0 编排）

```gdscript
## 由 CombatSystem 在 Phase 0 PREPARATION 的 _enter_phase() 中直接调用
func tick_all(field_characters: Array) -> void:
    # Phase 0 开始时执行倒计时——仅递减 duration，不发射 status_updated
    # （递减 1 不是用户可见的变更——避免每帧 48 次信号发射）
    for character in field_characters:
        var status_ids := _by_target.get(character.id, [])
        if status_ids.is_empty():
            continue
        for status_id in status_ids:
            var status := _instances[status_id]
            if status.duration > 0:                    # 永久状态 (duration=-1) 不递减
                status.duration -= 1
                if status.duration == 0:
                    status.is_expired = true

    # Phase 0 结算完成后统一移除过期状态——对每个被移除的状态发射 status_removed
    # ⚠️ 延迟移除确保"回合开始触发"效果仍能看到 duration=1 的状态
    for character in field_characters:
        remove_expired_statuses(character.id)

## status_updated 仅在用户可见的状态变更时发射（层数变化、数值重算、
## 来自非倒计时来源的持续时间变更）——不在每帧递减时发射
```

**信号发射策略详解**：
- `tick_all()` 的 duration 递减 → **不发射** `status_updated`（每帧 48 次信号发射是浪费——递减不是用户可见事件）
- `remove_expired_statuses()` → 对每个被移除的状态发射 `status_removed`（最坏情况 48 次/帧 × ~0.005ms = 0.24ms，远在帧预算内）
- `status_updated` → 仅在层数变化（叠加/部分移除）、数值重算（刷新）、来自 apply_status / remove_status 等非倒计时来源的持续时间变更时发射

### 免疫检查链

```
can_apply(target_id: int, template: StatusTemplate) → bool:

  # 第一级：类型免疫（如"免疫所有减益"）
  if _has_type_immunity(target_id, template.type):
      return false  # 短路——不检查后续级别

  # 第二级：模板免疫（如"免疫冰冻"——精确匹配 template_id）
  if _has_template_immunity(target_id, template.template_id):
      return false

  # 第三级：属性免疫（如"免疫火系伤害"——查 metadata.damage_type）
  var damage_type: String = template.metadata.get("damage_type", "")
  if not damage_type.is_empty() and _has_element_immunity(target_id, damage_type):
      return false

  return true
```

免疫判定来自角色被动技能、装备效果和已施加的免疫类状态（如"冰心诀——免疫冰冻"）——StatusEffectSystem 内部维护 `_immunity_flags: Dictionary[int, Array[StringName]]`（key=target_id → 免疫标签列表）供此检查使用。

### Cat 2b 信号总线

| 信号 | 载荷 | 发射时机 | 主要消费者 |
|------|------|---------|-----------|
| `status_applied` | `{target_id: int, status_id: int, template_id: StringName, stacks: int, reason: String}` | `apply_status()` 成功后 | CombatUI（创建角色头顶图标）、AudioSystem（施加音效） |
| `status_removed` | `{target_id: int, status_id: int, template_id: StringName, reason: String}` | 状态被移除时（过期/手动/溢出驱逐） | CombatUI（销毁图标+淡出动画）、HUD（tooltip 关闭） |
| `status_updated` | `{target_id: int, status_id: int, changes: Dictionary}` | 层数/数值/duration 变更时（不含每帧递减——见 §持续时间倒计时 信号发射策略） | CombatUI（数字跳变动画）、HUD（tooltip 刷新） |
| `status_immunity_blocked` | `{target_id: int, template_id: StringName, immunity_type: String}` | `can_apply()` 返回 false 时 | CombatUI（"免疫"文字弹出） |

所有 Cat 2b 信号通过 ADR-0007 的 `_emit_signal_safe` 包装器发射——信号链深度在此路径中得到追踪和截断保护。

**不通过信号传播的内容**：
- **属性修正值** → 消费者通过 `get_accumulated_value(target_id, stat_name)` 主动查询（每帧被调用多次——信号传播会产生不必要的开销）。CombatSystem 在伤害计算时调用，CombatUI 在更新 ATK/DEF 显示时调用
- **GSM 不转发状态信号**——状态导致的属性变更在消费者查询 `get_accumulated_value()` 时动态计算，而非通过 GSM `batch_updated` 传播（与 ADR-0007 Cat 1 信号互补——状态数值的"不确定性"（动态叠加+过期+暂挂）使其不适合进入状态快照链）

### 属性累计修正

```gdscript
func get_accumulated_value(target_id: int, stat_name: String) -> float:
    var total: float = 0.0
    var status_ids := _by_target.get(target_id, [])
    for status_id in status_ids:
        var status := _instances[status_id]
        if status.is_expired or status.is_hidden:
            continue                          # 隐藏/过期状态不计入
        if not _affects_stat(status, stat_name):
            continue
        total += status.value * float(status.current_stacks)
    return total
```

**为什么不是 GSM Cat 1 信号传播**：属性修正值是动态计算的——4 个变量同时影响结果（活跃状态列表、层数、value、is_expired/is_hidden 标志）。通过 GSM `batch_updated` 传播每一次细微变更会创建指数级的信号事件（状态 A 层数+1 → batch_updated → 6 个 CombatUI 元素刷新 → 每个元素调用 get_accumulated_value）。主动查询模式消除了中间信号——消费者在需要时单次调用即获最终值。

### 角色阵亡/复活的暂挂恢复

```
suspend_statuses_by_source(source_card_instance_id: int) → Array[Dictionary]:
  # 仅处理非绑定来源的状态（敌方 debuff、丹药 buff、通用卡牌效果等）
  # 绑定来源的状态由 BindingSystem 独立处理（永久移除——binding-system.md §7）
  affected_ids := []
  for status_id in _instances:
    if _instances[status_id].source_card_instance_id == source_card_instance_id:
      if _is_binding_source(status_id):
        continue   # 跳过绑定来源——BindingSystem 负责永久移除
      snapshot := _serialize_instance(_instances[status_id])
      affected_ids.append(snapshot)
      _remove_instance(status_id, "suspended")
  return affected_ids

restore_statuses(suspended_snapshots: Array[Dictionary]) → int:
  restored_count := 0
  for snapshot in suspended_snapshots:
    instance := _deserialize_instance(snapshot)
    if instance.source_card_instance_id 对应的来源卡牌仍在游戏中:
      _register_instance(instance)
      restored_count += 1
    else:
      log_warn("Status suspended source no longer available: %s" % instance.template_id)
  return restored_count
```

**与 GDD §6 接口定义的差异说明**：`suspend_statuses_by_source()` 的返回类型从 GDD 的 `[String]`（ID 列表）变为 `Array[Dictionary]`（序列化快照列表）。原因：`restore_statuses()` 需要完整的字段快照（duration、value、current_stacks、applied_turn 等）以在复活时重建状态实例——仅恢复 ID 列表不足以完成此操作。序列化快照在暂挂期间保留完整的字段状态，`restore_statuses()` 使用这些快照调用 `_deserialize_instance()` 创建新的 StatusInstance。

### 与 ADR-0009（卡牌效果引擎）的接口映射

ADR-0009 §子系统集成契约 以 proposed contract 形式引用了 StatusSystem API——当时预期的 ADR 编号为 ADR-0013（状态效果系统），实际编号为 ADR-0011。本 ADR 定义的接口与 ADR-0009 假设的接口之间存在以下差异，需在接受本 ADR 后同步更新 ADR-0009：

| API | ADR-0009 假设（proposed contract） | ADR-0011 实际定义 | 差异说明 |
|-----|----------------------------------|-----------------|---------|
| `apply_status()` | `(target_id, template: StatusTemplate) → ApplyResult` | `(target_id: int, template_id: StringName, source_card_instance_id: int, overrides: Dictionary = {}) → ApplyResult` | `template` 对象 → `template_id` 字符串（内部通过 `get_status_template()` 查找）；新增 `source_card_instance_id`（追溯来源）和 `overrides`（效果引擎覆盖 base_value）参数 |
| `remove_status()` | `(status_id) → bool` | `(status_id: int) → bool` | 类型精确化：String → int |
| `remove_statuses_by_source()` | `(target_id, source_id) → int` | `(target_id: int, source_card_instance_id: int) → int` | 参数名精确化，语义相同 |
| `get_active_statuses()` | `→ Array[StatusEffect]` | `→ Array[int]`（status_id 列表） | 返回 ID 列表而非完整对象——消费者通过 `get_status_instance(status_id)` 获取完整 StatusInstance |
| `get_accumulated_value()` | `(target_id, stat_name) → float` | `(target_id: int, stat_name: String) → float` | 类型精确化，已满足契约 |
| `get_statuses_by_type()` | 未在 ADR-0009 中引用 | `(target_id: int, type: StatusType) → Array[int]` | 新增——按类型过滤的便捷查询 |

**更新行动**：在接受 ADR-0011 后，需更新 ADR-0009 的以下位置：
- §子系统集成契约（约第 178-214 行）：将 `ADR-0013` 引用替换为 `ADR-0011`，更新接口签名以匹配上表
- §ADR 依赖关系（约第 25 行）：将 `ADR-0013（状态效果系统——...）` 替换为 `ADR-0011（状态效果系统——...）`
- §后果 → 风险（约第 384 行）：将 `ADR-0013（状态效果系统）尚不存在` 替换为引用本 ADR
- §相关决策（约第 433 行）：将 `ADR-0013` 替换为 `ADR-0011`

### Autoload 初始化

```
StatusEffectSystem 初始化顺序（Autoload #8——完整链 11 个 Autoload）：

  #1  GSM              (Foundation, ADR-0001)
  #2  InputManager      (Foundation, ADR-0005)
  #3  SceneManager      (Foundation, ADR-0006)
  #4  SaveLoad           (Foundation, ADR-0003)
  #5  EventSystem        (Foundation, ADR-0004)
  #6  CardSystem         (Core, ADR-0002)
  #7  CostSystem         (Core)
  #8  StatusEffectSystem (Core)  ← 本 ADR
  #9  CombatSystem       (Feature, ADR-0008)
  #10 CardEffectEngine   (Feature, ADR-0009)
  #11 RealmSystem        (Core, ADR-0010)

_ready():
  1. 等待 gsm_initialized 信号（ADR-0001）——确保 GSM 可读（查询 player.* / battle.*）
  2. 加载 StatusTemplate 注册表：
     a. 扫描 res://assets/statuses/ 目录（与 CardSystem 的 res://assets/cards/ 加载模式一致）
     b. 加载所有 .tres StatusTemplate Resource
     c. 注册到 _templates: Dictionary[StringName, StatusTemplate]
     d. 发射 status_templates_loaded(count: int) → Cat 2b（CardSystem 可能等待此信号验证状态引用完整性）
  3. 初始化内部注册表为空——运行时状态在战斗开始后按需填充
  4. 不创建默认状态——所有状态由卡牌效果引擎在战斗过程中通过 apply_status() 创建
```

**Godot Autoload 初始化顺序保证**：Godot 按 `project.godot` 的 `[autoload]` 列表顺序逐个同步调用每个 Autoload 的 `_ready()`——下层 `_ready()` 在上层完整返回后才执行。Godot 4.0 至 4.6 行为一致。StatusEffectSystem（#8）执行时 GSM-CostSystem（#1-#7）已完全初始化。

### 对象池策略

StatusInstance 采用直接 `RefCounted.new()` / 引用计数归零模式——**不使用对象池**。理由：
- Godot 的 `RefCounted` 使用即时引用计数（引用计数归零时立即释放——非追踪式 GC，无 GC 暂停）
- 状态实例的创建频率低（每卡牌打出 1-3 次 `apply_status()`，Phase 2 期间约 5-20 次/回合）——非逐帧热路径
- 状态实例的存续时间跨度为多个回合——生命周期与逐帧创建/销毁的粒子/伤害数字完全不同
- 若 Godot Profiler 下 60fps 目标中出现可测量的帧时间峰值再考虑实施对象池

## 考虑的替代方案

### 替代方案 A：纯 Dictionary 动态类型（无类层级）

- **描述**：所有状态实例使用 `Dictionary` 存储字段（`{"template_id": "poison_3", "duration": 3, ...}`），通过 `match status.type:` 分支处理叠加逻辑。与 GDD 当前定义的 StatusEffect 数据结构一致——GDD 使用伪代码块而非 GDScript 类定义。
- **优点**：零 RefCounted 对象分配——无 GC 压力；策划可以通过 JSON/CSV 编辑状态数据（而非 `.tres` Resource）；与 Godot 的类型化 Array[Dictionary] 兼容性更好
- **缺点**：无编译时类型安全——`Dictionary.get("duration", 0)` 的字符串键拼写错误在编译时无法捕获；`match` 分支遗漏不在编译时捕获（需 100% 测试覆盖）；无法使用 Inspector 编辑——策划失去可视化编辑能力；220+ 状态模板 × 每战斗 50+ 实例的规模下，运行时错误（键名错误、类型不匹配）的调试成本远高于编译时类型安全的收益
- **拒绝原因**：GDD 开放问题 #1 的建议方向是 RefCounted——本 ADR 采用了此建议。220 个状态模板的规模证明了编译时类型安全的价值——与 ADR-0009（效果引擎拒绝纯 Dictionary 方案的理由一致）

### 替代方案 B：状态数据存储在 GSM battle.temp_effects 域

- **描述**：活跃状态数据直接存储在 `GSM.battle.temp_effects` 字典中——StatusEffectSystem 只是操作这些数据的服务层（不持有内部状态）。与 GDD §依赖关系的原始描述一致。
- **优点**：单一数据源——状态数据与 HP、费用、回合数等其他战斗数据在同一位置（GSM）；存档/读档自然覆盖——GSM.serialize() 自动包含状态数据；无需 `_instances` / `_by_target` 内部索引
- **缺点**：GDD 自身矛盾——§7 信号广播建议独立信号总线而 §依赖关系建议 GSM 存储；GSM 字典存储序列化 Dictionary（非 RefCounted 对象引用）→每次叠加/倒计时操作需序列化/反序列化→每帧 50+ 状态实例的序列化开销累积；`get_active_statuses(target_id)` 需遍历全部 GSM 字典（O(n)）而非 StatusEffectSystem 的 `_by_target` 索引（O(1)）
- **拒绝原因**：性能路径差异是决定性的——`get_active_statuses()` 每帧被 CombatUI 调用 2+ 次（场上 6+ 角色），`get_accumulated_value()` 在每次伤害计算中被调用。GSM 字典存储需要额外序列化/反序列化步骤和 O(n) 遍历——这些是战斗热路径。StatusEffectSystem 内部索引提供 O(1) 角色级查询和直接对象引用。战斗结束时向 GSM 导出序列化快照即可满足存档需求

### 替代方案 C：每角色独立 StatusEffectComponent（非中央 Autoload）

- **描述**：每个角色节点持有自己的 `StatusEffectComponent` 子节点——状态实例直接附加到角色 Node 上。施加/移除/倒计时操作在组件内部独立执行。StatusEffectSystem Autoload 仅持有模板注册表和全局配置。
- **优点**：分散式——无中央瓶颈，每个角色的状态操作天然隔离；Godot 惯用模式——Component 子节点的生命周期由场景树管理（角色移除时状态自动清理）；不需要 `_by_target` 索引（每个 Component 只管理自己的状态）
- **缺点**：跨角色状态查询（如"查找场上所有带中毒状态的角色"）需要遍历所有角色节点→调用其 Component → 汇总结果；CombatSystem 在 Phase 0 需要遍历全场角色调用 Component.tick()——与中央 `tick_all(field_characters)` 无本质差异但增加了节点访问开销；免疫检查需要跨角色数据（"敌方是否有免疫光环？"）→ Component 模式不自然
- **拒绝原因**：状态系统是 Core 层基础设施——被 6+ 系统消费，中央 API（`get_accumulated_value()`）是它的核心价值。Component 模式适合"角色自身的独立行为"（如动画控制器、移动控制器），不适合"需要全局查询和批量操作的状态数据库"。与 CombatSystem 的编排器模式（中央调度→子系统响应）一致——StatusEffectSystem 作为中央服务，CombatSystem 在 Phase 0 传递全场角色列表执行批量倒计时

## 后果

### 积极的

- **双层模型的一致性**：StatusTemplate/StatusInstance 与 CardTemplate/CardInstance（ADR-0002）、EffectTemplate/EffectInstance（ADR-0009）构成统一的 Template/Instance 三元组——程序员无需记忆不同的对象模型规则
- **O(1) 角色级状态查询**：`_by_target` 索引 + `_instances` 字典——`get_active_statuses(target_id)` 和 `get_accumulated_value(target_id, stat)` 在战斗热路径上 O(1)
- **专用 Cat 2b 信号避免 GSM 信号表膨胀**：4 个 StatusEffectSystem 信号（vs 如果通过 GSM batch_updated 传播 → 每帧 50+ 状态 × 6 角色的数据变更事件），保持 GSM 信号表的可维护性
- **GDD 开放问题全部解决**：#1（双层模型）→ StatusTemplate/StatusInstance；#2（max_stacks 来源）→ StatusTemplate 定义；#3（隐藏状态）→ 公式中排除 is_hidden
- **与 CombatSystem 编排器模式一致**：tick_all() 由 CombatSystem 在 Phase 0 直接调用——编排器→子系统模式，与 ADR-0008 的 9 个子系统调度一致
- **GDD §依赖关系 vs §7 信号广播的矛盾已解决**：运行时状态存储在 StatusEffectSystem 内部，GSM 仅在战斗结束时接收快照——消除了"状态数据既在 GSM 中又通过独立信号总线通知"的架构歧义

### 消极的

- **Autoload 数量增加到 11 个**：+1 Autoload 增加初始化顺序的脆弱性——StatusEffectSystem 必须在 CardSystem+CostSystem 之后、CombatSystem+CardEffectEngine 之前注册
- **双层模型的学习成本**：程序员需理解 StatusTemplate（Resource，只读策划数据）vs StatusInstance（RefCounted，运行时变量）的边界——与 CardSystem 和 CardEffectEngine 相同，但增加了第三个需要掌握的系统
- **GSM 不再是"一切状态的唯一数据源"**：活跃状态实例存在于 StatusEffectSystem 内部——调试时不能仅查看 GSM 字典了解完整的战斗状态（需同时检查 StatusEffectSystem 注册表）。缓解措施：`serialize_all()` 导出方法可在开发控制台中调用。**注意**：此例外在 `docs/architecture.md` §架构原则 #1 中显式记录——"战斗中活跃状态实例由 StatusEffectSystem Autoload 管理（非 GSM），仅战斗结束时导出快照至 GSM"
- **`_suspended` 暂挂注册表**：角色阵亡/复活路径增加了一个边缘状态存储——永久死亡时的清理、暂挂期间来源卡牌被移除的处理增加复杂度
- **帧预算风险**：最坏场景——Phase 0 tick 遍历 6+ 角色 × 20 状态/角色 × 免疫光环检查 = 120+ 状态实例的倒计时操作。需要在 1ms 预算内完成（每个状态 ~8μs）

### 风险

- **RefCounted GC 抖动**：每战斗 50+ StatusInstance 创建/销毁——Godot 使用即时引用计数（非追踪式 GC），RefCounted 在引用计数归零时立即释放，不会产生 GC 暂停。Godot 4.5 优化了引用计数操作性能。当前规模下无需对象池——若 Godot Profiler 显示帧时间峰值，再实施对象池预分配（`_instance_pool: Array[StatusInstance]` 复用频繁创建/销毁的实例）
- **`_by_target` 索引与 `_instances` 注册表的一致性**：两个字典必须保持同步——`_instances` 中的每个条目在 `_by_target[target_id]` 中必须有对应记录。缓解措施：所有 StatusInstance 的注册/注销通过 `_register_instance()` / `_remove_instance()` 私有方法集中处理——同时更新两个字典
- **暂挂状态的来源卡牌引用断裂**：角色阵亡后状态暂挂——若在暂挂期间来源卡牌被弃牌/移除（如敌方逃跑），`restore_statuses()` 检查来源可用性时发现断开。缓解措施：来源不可用时状态自动移除 + WARN 日志——GDD §边缘情况已定义此行为
- **状态溢出驱逐的选择偏向**：最旧非永久状态优先驱逐——但永久状态（duration=-1）默认不受驱逐——恶意永久状态 spam 可能耗尽角色的状态槽位。缓解措施：永久状态在 `count_active_statuses()` 中计入——当一个角色的永久状态占比超过 50% 时发出 WARN 日志；`clear_all_statuses()` 清理非永久状态的逻辑不受影响
- **StatusEffectSystem API 契约的跨 ADR 一致性**：本 ADR 定义的 `apply_status()` / `get_accumulated_value()` / `remove_statuses_by_source()` 等接口已被 ADR-0009（卡牌效果引擎）以 proposed contract 形式引用——若本 ADR 的接口签名与 ADR-0009 的假设不一致，需同步更新 ADR-0009 的集成契约

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| status-system.md | §1 状态数据结构——11 个强类型字段 | StatusInstance RefCounted 类——14 个字段（status-system.md 的 11 个 + `id`、`target_id`、`source_card_instance_id`、`priority`、`is_expired` 运行时追踪字段） |
| status-system.md | §2 状态生命周期——创建→施加检查→施加/合并→持续跟踪→倒计时/触发→到期移除 | `apply_status()` 管线——template 加载→免疫检查→溢出预检查→同名查找→叠加判定→实例注册→信号发射；`tick_all()` 倒计时→过期标记→延迟移除 |
| status-system.md | §3 叠加规则——独立/刷新/叠加上限 3 种 | `apply_status()` 的 match 分支——STACK_INDEPENDENT 创建新实例 / STACK_REFRESH 刷新 duration+value / STACK_CUMULATIVE 增加层数（检查 max_stacks 上限） |
| status-system.md | §4 持续时间倒计时——Phase 0 开始递减 + 结算后移除 | `tick_all()`——倒计时循环 duration-1 + is_expired 标记；`remove_expired_statuses()` 延迟到 Phase 0 结算后执行。递减不发射 status_updated，仅批量移除发射 status_removed |
| status-system.md | §5 免疫判定——类型免疫→模板免疫→属性免疫三级短路检查 | `can_apply()`——三级短路求值；`_immunity_flags` 字典追踪目标的免疫标签列表 |
| status-system.md | §6 接口规范——apply/remove/suspend/restore/clear + 查询 + get_accumulated_value | 6 个公共写入 API + 5 个查询 API + `get_status_template()` 模板查询——完整实现 GDD 指定的接口契约，并满足 ADR-0009 的 proposed contract |
| status-system.md | §7 信号广播——status_applied/removed/updated/immunity_blocked | 专用 Cat 2b 信号总线——4 个信号由 StatusEffectSystem Autoload 直接发射（通过 `_emit_signal_safe` 路由）；CombatUI/HUD 直接订阅 |
| status-system.md | §8 属性累计修正——多个状态同属性加法叠加 | `get_accumulated_value()`——遍历活跃状态（排除过期/隐藏）→ `value × current_stacks` 加法累加 |
| status-system.md | §边缘情况——21 个极端场景的处理 | 每个边缘情况对应本 ADR 的决策：角色阵亡→ suspend/restore；溢出驱逐→最旧非永久优先；max_stacks 拒绝→不刷新 duration；移除不存在→返回 false + DEBUG 日志 |
| combat-system.md | Phase 0 状态倒计时——准备阶段统一递减 | `tick_all(field_characters)` 由 CombatSystem 在 Phase 0 的 `_enter_phase()` 中直接调用——编排器→子系统模式 |
| card-effect-engine.md | §子系统集成契约——APPLY_STATUS/REMOVE_STATUS/MODIFY_STAT 效果类型 | `apply_status()` / `remove_status()` / `get_accumulated_value()` / `remove_statuses_by_source()` 接口提供效果引擎的状态操作能力——满足 ADR-0009 §子系统集成契约的 proposed contract |
| architecture.md §模块归属 | CORE 层——StatusEffectSystem 被 6+ 系统消费 | StatusEffectSystem 位于 Autoload #8（Core 层）——在 CardSystem+CostSystem 之后、CombatSystem+CardEffectEngine 之前 |

## 性能影响

- **CPU**：`apply_status()` 单次调用（模板查找+免疫检查+同名查找+叠加判定+注册表更新）<0.05ms。`tick_all()`（全场角色状态倒计时+过期移除）<1ms（6 角色 × 平均 8 状态/角色 = 48 次 duration 递减 + 过期检查；递减不发射信号）。`get_accumulated_value()` 单次 <0.01ms（遍历最多 20 个活跃状态 × 2 次/伤害计算）
- **内存**：每个 StatusInstance RefCounted 实例 ~200 bytes × 最多 20 状态/角色 × 6 角色 = ~24KB 活跃状态内存。`_by_target` Dictionary 索引（6 角色 × Array[status_id 列表]）+ `_instances` Dictionary（最多 120 entries × int→RefCounted 映射）= ~20KB 索引开销。StatusTemplate Resource 在磁盘上 ~300-800 bytes/模板 × 预估 50-80 状态模板 = 约 15-64KB 磁盘占用（`.tres` 文本格式）
- **加载时间**：50-80 个 StatusTemplate Resource 的同步加载（`ResourceLoader.load()` 在主线程）预计 <30ms——与 CardSystem（222 模板，<100ms）和 CardEffectEngine（222 模板）共享启动画面时间窗口。若超过则切换到 `ResourceLoader.load_threaded_request()` 异步加载
- **网络**：不适用（单人游戏）

## 迁移计划

不适用——这是新系统的初始架构决策。无现有状态系统需要迁移。

若未来需要从 GDD 的 Dictionary 原型迁移到 Resource+RefCounted 模型：
1. 创建 `StatusTemplate` Resource 类——将 GDD 的伪代码字段（template_id、type、stack_rule、max_stacks、base_duration、base_value、icon_path、description_tmpl、default_priority、metadata）映射为 `@export` GDScript 变量
2. 编写脚本将 GDD 中设计的 50-80 个状态条目批量导出为 `.tres` 文件
3. 更新 GDD 引用——将"StatusEffect 数据结构"伪代码块替换为指向本 ADR 的链接

## 验证标准

- 通过 GUT：`StatusEffectSystem` 测试套件覆盖：
  - `apply_status()` 独立叠加规则 → 创建独立实例（两个同名独立状态并存）
  - `apply_status()` 刷新规则 → duration 刷新为 max(old, new)，不创建新实例
  - `apply_status()` 叠加上限规则 → 层数+1 直到 max_stacks 后拒绝
  - `can_apply()` 免疫检查——类型免疫（减益免疫拒绝所有 BUFF/DEBUFF/SPECIAL 中的 DEBUFF）、模板免疫（精确 template_id 匹配拒绝）、属性免疫（damage_type 匹配拒绝）
  - `tick_all()` 倒计时——duration=3 的状态在 3 次 tick 后 is_expired=true 并在 remove_expired_statuses() 中被移除
  - `tick_all()` 永久状态——duration=-1 不被倒计时递减或移除
  - `tick_all()` 信号发射——递减不发射 status_updated；仅 remove_expired 发射 status_removed
  - `get_accumulated_value()` 叠加——2 个不同 ATK 状态各 +2 → 返回 4.0
  - `get_accumulated_value()` 隐藏状态——is_hidden=true 不计入
  - `get_accumulated_value()` 过期状态——is_expired=true 不计入
  - `suspend_statuses_by_source()` → `restore_statuses()` 往返——恢复后 duration 及其他字段与暂挂前一致
  - 溢出驱逐——第 21 个状态施加时最旧非永久/非隐藏状态被移除（status_removed reason="overflow"）
  - 信号发射验证——`status_applied` / `status_removed` / `status_updated` / `status_immunity_blocked` 在对应操作后发射
- 通过集成测试：
  - CombatSystem Phase 0 调用 `tick_all()` → 全场角色状态 duration 递减 → 过期状态移除
  - CardEffectEngine 通过 `apply_status()` 施加状态 → StatusEffectSystem 注册实例 → CombatUI 通过 Cat 2b 信号接收到 `status_applied`
  - 角色阵亡 → 非绑定状态暂挂 → 复活恢复——完整往返流程
  - 战斗结束 → `clear_all_statuses()` 清理所有非永久状态

## 相关决策

- ADR-0001（GSM——只读查询 player.*/battle.*；战斗结束时接收状态快照）
- ADR-0002（CardSystem——Template/Instance 分离模式——本 ADR 的 StatusTemplate/StatusInstance 三元组之一）
- ADR-0007（信号分类——4 个 Cat 2b 信号 + 直接方法调用编排）
- ADR-0008（CombatSystem——Phase 0 发动 tick_all()；Phase 2/4/5 发动 apply/remove；battle_end 发动 clear_all）
- ADR-0009（CardEffectEngine——apply_status/remove_status/get_active_statuses/get_accumulated_value/remove_statuses_by_source 的 proposed contract）
- ADR-0010（RealmSystem——境界压制可能影响状态效果强度——未来交叉决策）