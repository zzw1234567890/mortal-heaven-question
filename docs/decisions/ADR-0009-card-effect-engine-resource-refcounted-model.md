# ADR-0009：卡牌效果引擎 — Resource 模板 + RefCounted 运行时实例 + 栈式结算

## 状态
Accepted（2026-07-26——Feature 层审查通过。修复：Foundation 编号偏移 ×4、ADN0008 拼写→ADR-0008、ADR-0010→0016（DeploymentSystem）、ADR-0011→0017（AI）、Foundation 计数 7→5、CostSystem "待 ADR"→ADR-0015、StatusSystem 风险更新为已 Accepted、ADR-0016 资产管线引用移除。）

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Card Effect Engine |
| **知识风险** | HIGH（Godot 4.5 引入 `@abstract` 类、GDScript 可变参数、类型化数组——均在 LLM 训练截止 2025-05 之后） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/deprecated-apis.md`、`docs/engine-reference/godot/modules/ui.md` |
| **使用的截止后 API** | Godot 4.5 `@abstract`（效果基类 `EffectBase`——强制子类实现 `_resolve()`）；GDScript 可变参数 `register_effect(type, handler: Callable, config := {})`（4.5 语法）；类型化 `Array[EffectInstance]`（4.4+ 泛型数组）；`RefCounted` 子类层级（4.x 稳定——但 4.5 优化了引用计数性能） |
| **需要验证** | `RefCounted` 子类在 500+ 实例/帧 下的 GC 抖动（Godot 4.5 引用计数优化后的实际表现）；`@abstract` 虚函数调用开销 vs `Callable` 回调（`_resolve()` 每效果每帧调用）；`Array[EffectInstance].filter()` 在队列重排序中的性能（100+ 元素）；`Array[EffectInstance]` 的 `front()`/`back()`/`pop_front()` 方法在 Godot 4.6 中的行为；`@abstract` 应用于 `extends RefCounted` 类时是否阻止 `.new()`（Godot 4.5 新特性——需 GUT 测试验证后再提交效果层级）；`DirAccess` 在导出 PCK 构建中的 `res://` 目录扫描行为——若 `assets/cards/effects/` 在 PCK 内不可遍历，需切换到清单 Resource（包含所有 EffectTemplate 路径的预编译 `.tres`） |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——只读上下文：`player.*` / `battle.*` / `narrative.*` / `session.*`；不直接写入 GSM——效果结果通过各子系统接口写入）；ADR-0006（CardSystem——`get_template(id)` 模板查询、`create_instance()` / `serialize_instance()` 实例工厂——Template/Instance 分离模式）；ADR-0003（EventSystem——`SET_FLAG` 效果类型通过 `EventSystem.set_flag()` 委托写入；共享 `OutcomeType` 枚举词汇表——本 ADR 扩展非复制）；ADR-0007（三分类信号体系——效果生命周期信号归类为 Cat 2b；状态变更通过 GSM Cat 1 信号传播；直接调用编排子系统）；ADR-0008（CombatSystem——7 阶段转换触发效果结算入口：Phase 0 tick、Phase 1 抽牌时触发、Phase 2 出牌、Phase 3 攻击声明、Phase 4 攻击结算、Phase 5 敌方行动、Phase 6 回合结束；CombatSystem 在 `advance_phase()` 成功后发射 `phase_changed(old_phase, new_phase, turn)` [Cat 2b]——效果引擎不订阅此信号，由 CombatSystem 通过直接调用 `resolve_phase_effects()` 编排） |
| **启用** | ADR-0017（AI 系统——`evaluate_effect()` / `simulate_chain()` / `GameStateSnapshot` 评估接口）、ADR-0011（状态效果系统——`apply_status()` / `remove_status()` / `get_accumulated_value()` 接口）、ADR-0016（上场阵位系统——对场上角色的效果结算需要角色位置信息） |
| **阻塞** | 卡牌效果 Epic（所有卡牌效果的运行时结算——伤害、治疗、buff/debuff、绑定、阵法激活、触发式效果）、战斗 Epic（阶段 0/2/3/4/5/6 的效果触发）、AI Epic（敌方出牌决策的评估接口）、状态效果 Epic（状态施加/移除/查询的实现依赖引擎接口） |
| **排序说明** | Feature 层第一个 ADR——在 Foundation 层全部 5 个 ADR + CombatSystem (ADR-0008) 被接受后编写。Autoload 初始化顺序见 §对象生命周期——CardEffectEngine 为 Autoload #10（在 CardSystem #6、CostSystem #7、StatusEffectSystem #8、CombatSystem #9 之后）。必须在 AI 系统（ADR-0017）之前被接受——AI 评估接口依赖效果引擎的干跑评估能力 |

## 上下文

### 问题陈述

`card-effect-engine.md` GDD 定义了完整的运行时效果解析架构——4 种效果类型（即时/持续/触发式/替代）、5 级结算优先级（主动出牌→先发己方→普通己方→敌方→instance_id）、中分辨率插入队列模型、触发链深度限制 10 层 + 循环检测、PRD 伪随机分布、以及 AI 干跑评估接口。但 GDD 关注的是"效果应该做什么"，本 ADR 需要解决的是"效果如何在 Godot 4.6 中工程化实现"：

1. **对象模型选择**：效果数据结构在 Godot 中的表示方式——Resource 子类（模板，Inspector 可编辑）vs RefCounted 子类（运行时实例，轻量级）vs 纯 Dictionary 动态类型。GDD 开放问题 #1 明确提出了此选择（"Resource 用于模板 + RefCounted 类层级用于运行时"）。
2. **结算引擎的调度模型**：效果进入队列 → 优先级排序 → LIFO 栈式出栈 → 中分辨率插入新效果。这与 ADR-0008 的战斗阶段推进是独立的调度层——战斗系统负责"何时结算"（阶段 0/2/3/4/5/6），效果引擎负责"如何结算"（栈管理 + 优先级排序 + 触发链控制）。
3. **信号 vs 直接调用的边界**：效果引擎的效果生命周期事件（注册/移除/暂挂/恢复）应使用 Cat 2b 系统信号——哪些子系统直接订阅、哪些通过 GSM Cat 1 传播状态变更——需要与 ADR-0007 决策矩阵对齐。
4. **子系统集成契约**：效果引擎读取 CardSystem 模板、调用 StatusSystem 施加/移除状态、查询 BindingSystem 的预计算 multiplier、委托 EventSystem 写入 story_flags、通过 CombatSystem 的 phase 信号接收触发时机——这些跨系统调用的方向和数据流需要在本 ADR 中明确规定。
5. **`OutcomeType` 共享词汇表**：`architecture.md` OQ-05 问"卡牌效果引擎与事件系统的 Outcome 类型是否应统一为共享词汇表"。本 ADR 决定：**是——效果引擎扩展 ADR-0003 的 `OutcomeType` 枚举**（新增 `APPLY_STATUS`、`MODIFY_STAT`、`TRIGGER_CHAIN`、`ACTIVATE_FORMATION`、`MODIFY_COST`），而非创建重复的枚举类型。

### 约束

- **效果类型体系**：4 大类（即时/持续/触发式/替代）覆盖全部 222 张卡牌——新卡牌效果必须落入现有类型，不引入新的顶级类型
- **模板/实例分离**：CardTemplate（Resource）只读——所有运行时可变状态在 EffectInstance（RefCounted）上管理（与 ADR-0006 的 Template/Instance 分离模式一致）
- **栈式结算**：LIFO 出栈 + 中分辨率插入队列——新触发的效果按优先级重新插入队列，而非追加到末尾
- **触发链硬限制**：最大深度 10 层 + 循环检测（同一 `card_instance_id` 不重复触发）——GDD §边缘情况明确要求
- **PRD 确定性**：PRNG 种子来自 `GSM.meta.seed`——同种子+同操作序列 = 完全相同的概率结果（支持重播和回归测试）
- **GSM 不直接写入**：效果引擎不调用任何 GSM 写入方法——效果结果通过子系统接口间接写入（StatusSystem、BindingSystem、CombatSystem 各自负责自己的 GSM 写入）
- **Feature 层定位**：效果引擎属于 Feature 层（与 architecture.md §模块注册表一致）——依赖 Foundation 层（GSM、EventSystem）和 Feature 层同类（CombatSystem、BindingSystem），但不被 Foundation 层依赖。Foundation 层原则 #3 遵守
- **帧预算**：单次 `resolve_card()` 调用（含栈结算 + 触发链）<2ms；单次 `evaluate_effect()` 干跑评估 <100μs；AI 回合评估总预算 ~30ms（跨帧分摊）
- **Godot 4.5 `@abstract`**：效果基类 `EffectBase` 声明为 `@abstract`——强制子类实现 `_resolve()` 虚函数。Godot 4.5 之前不支持此语法——这是我们在 4.6 中依赖的截止后 API

### 需求

- 4 种效果类型的 `RefCounted` 子类层级：`InstantEffect`、`PersistentEffect`、`TriggeredEffect`、`ReplacementEffect`（均继承 `EffectBase`）
- 效果模板使用 `Resource` 子类（`.tres` 文件，`@export` 字段）——策划在 Inspector 中编辑
- 运行时效果实例由 `EffectFactory` 从 Resource 创建——轻量级 `RefCounted` 对象，不持有 Resource 引用（注册表查询在 Autoload 层 `CardEffectEngine`，工厂本身不持有注册表——见 §双层对象模型）
- 栈式结算引擎：`ResolutionStack` 管理队列 + `_resolve_stack()` LIFO 出栈 + 中分辨率插入
- 5 级优先级排序（主动出牌 > 先发己方 > 普通己方 > 敌方 > instance_id）+ 次级 priority 字段决胜
- 触发链管理：深度计数器 + `visited_card_ids: Dictionary`（`Dictionary[int, bool]`——GDScript 无 `Set` 类型，使用字典键 O(1) 查找）循环检测 + 第 11 层截断 + WARN 日志
- PRD 引擎：独立 `PRDEngine` 内部类——`next_random(probability_5pct_step) → bool`，怜悯保护强制触发
- AI 评估接口：`evaluate_effect(card_id, target_id, snapshot) → EffectEvaluation` + `simulate_chain(...) → ChainPreview` + `create_evaluation_snapshot() → GameStateSnapshot`
- `OutcomeType` 枚举扩展——在 ADR-0003 的 12 种类型基础上新增 5 种效果专属类型
- 信号路由（ADR-0007 合规）：Cat 2b 信号 `effect_registered` / `effect_removed` / `effect_suspended` / `effect_restored` / `stack_overflow_warning`（由 CardEffectEngine Autoload 发射）；Cat 1 GSM 信号（状态变更通过 StatusSystem → GSM 传播，效果引擎不直接发射 GSM 信号）

## 决策

**效果引擎实现为 Feature 层 Autoload（CardEffectEngine），采用双层对象模型——Resource 子类（`EffectTemplate`，Inspector 可编辑的 `.tres` 卡牌效果定义）+ RefCounted 子类层级（`InstantEffect` / `PersistentEffect` / `TriggeredEffect` / `ReplacementEffect`，运行时轻量级实例）。结算使用栈式引擎——`ResolutionStack` 管理优先级队列 + LIFO 出栈 + 中分辨率插入新效果。触发链硬限制 10 层 + `visited_card_ids: Dictionary`（GDScript 4.x 无内置 `Set` 类型，使用 `Dictionary[int, bool]` 字典键 O(1) 查找）循环检测。概率效果使用 PRD 伪随机分布（5% 步进 + 怜悯保护）。AI 接口暴露干跑评估能力——不修改游戏状态，在不可变 `GameStateSnapshot` 上执行纯计算。**

### 双层对象模型

```
┌──────────────────────────────────────────────────────────────────┐
│                  CardEffectEngine 对象模型                        │
│                                                                   │
│  ┌─────────────────────┐          ┌──────────────────────────┐  │
│  │  EffectTemplate     │  加载    │  EffectInstance (运行时)   │  │
│  │  (Resource, .tres)  │────────→ │  (RefCounted, 轻量级)    │  │
│  │                     │ 工厂方法  │                          │  │
│  │  @export 字段：     │          │  template_id: StringName  │  │
│  │  - type: EffectType │          │  base_value: int          │  │
│  │  - base_value: int  │          │  target_spec: TargetSpec  │  │
│  │  - target_selector  │          │  conditions: Array        │  │
│  │  - conditions       │          │  source_card_instance_id  │  │
│  │  - animation_id     │          │  activation_sequence      │  │
│  │  - description_tmpl │          │  priority: int (次级决胜) │  │
│  └─────────────────────┘          └──────────────────────────┘  │
│                                                                   │
│  4 个 RefCounted 子类：                                          │
│  InstantEffect      — 立即结算（伤害/治疗/抽牌/弃牌/费用修改）    │
│  PersistentEffect   — 持续生效（功法/法宝/阵法/buff/debuff）     │
│  TriggeredEffect    — 条件触发（回合开始/攻击/击杀/延迟触发）     │
│  ReplacementEffect  — 拦截修改（替代阵亡/效果增幅/效果无效化）    │
└──────────────────────────────────────────────────────────────────┘
```

**模板与实例分离的设计理由**：
- **Resource 模板**：策划在 Godot Inspector 中创建和编辑（`@export` 字段 = 可视化编辑）。存储在 `assets/cards/effects/` 目录。`card-system.md` 的 `CardTemplate` 通过 `effect_template_ids: Array[StringName]` 引用效果模板。
- **RefCounted 实例**：运行时由 `EffectFactory.create_instance(template: EffectTemplate, source_card_instance_id: int) → EffectBase` 创建（纯构造——接受模板，不查注册表）。`template_id → EffectTemplate` 的注册表查询在高层 `CardEffectEngine.create_instance(template_id: StringName, source_card_instance_id: int)` 完成（查注册表 → 委托低层工厂）——两层职责分离（technical-director 裁决 2026-08-16）。实例轻量级——只含结算所需的最小字段集，不持有 Resource 引用（避免共享引用污染——模式与 ADR-0006 的 Template/Instance 分离一致）。
- **为什么不用纯 Dictionary**：类型安全（编译时检查枚举值、参数类型）、`@abstract` 虚函数派发（避免 `match`/`if` 链的性能开销）、与 Godot Inspector 集成（Resource 天然支持 `@export` 编辑）。

### 栈式结算引擎 (ResolutionStack)

```
┌──────────────────────────────────────────────────────────────────┐
│              ResolutionStack 结算流程                             │
│                                                                   │
│  ┌─────────────┐     ┌──────────────────┐     ┌──────────────┐  │
│  │ 战斗阶段触发 │ ──→ │ 收集该阶段所有    │ ──→ │ 优先级排序    │  │
│  │ (Cat 2b)    │     │ 待触发效果到队列   │     │ (5级主排序 + │  │
│  └─────────────┘     └──────────────────┘     │  priority决胜) │  │
│                                                └──────┬───────┘  │
│                                                       ↓           │
│  ┌──────────────┐     ┌──────────────────┐     ┌──────────────┐  │
│  │ 栈为空 →     │ ←── │ LIFO 出栈：     │ ←── │ 中分辨率插入  │  │
│  │ 阶段结算完成  │     │ pop() 栈顶效果   │     │ 新效果按优先级│  │
│  └──────────────┘     │ → _resolve()     │     │ 重新插入队列  │  │
│                       │ → 触发链深度检查  │     └──────────────┘  │
│                       │ → visited检测     │                       │
│                       └──────────────────┘                       │
│                                                                   │
│  结算优先级（主排序键——从高到低）：                                │
│  1. 主动出牌效果（当前回合方 `card_instance_id`）                  │
│  2. 标记「先发」的己方持续效果（`activation_sequence` 降序）       │
│  3. 未标记「先发」的己方持续效果（`activation_sequence` 降序）     │
│  4. 敌方持续效果（`activation_sequence` 降序）                    │
│  5. 同 `activation_sequence` → `card_instance_id` 升序决胜       │
│                                                                   │
│  次级决胜键：`priority: int`（仅在同主排序层级内生效）             │
└──────────────────────────────────────────────────────────────────┘
```

**中分辨率插入队列模型**：效果 A 结算过程中触发效果 B → B 按优先级插入尚未结算的队列位置，而非追加到末尾。这确保 A→B 的因果关系正确反映在结算顺序中（B 在队列中可能排在某些已在队列中的低优先级效果之前）。

**与战斗系统的接口**：战斗系统（ADR-0008）的 `advance_phase()` 在进入 Phase 0/1/2/3/4/5/6 时**直接调用** `CardEffectEngine.resolve_phase_effects(phase: CombatPhase)`——引擎从所有活跃效果中筛选该阶段应触发的效果，收集到 `ResolutionStack`，然后 `_resolve_stack()` 循环出栈直到队列为空。效果引擎是响应式服务——由 CombatSystem 主动调用，不订阅 CombatSystem 信号。Phase 1（抽牌阶段）的"抽牌时触发"效果也通过 `resolve_phase_effects(CombatPhase.DRAW)` 进入 ResolutionStack。

### 触发链管理

```
触发链深度追踪：
  root_card_instance_id: int        # 触发链的根卡牌（玩家打出的第一张卡）
  current_depth: int                # 当前深度（从 1 开始计）
  visited_card_ids: Dictionary  # Dictionary[int, bool]——key = card_instance_id
                                 # GDScript 4.x 无 Set 类型，使用字典键 O(1) 查找

_resolve_stack() 每次出栈：
  1. current_depth += 1
  2. if current_depth > 10:         # 硬限制——GDD §边缘情况
       effect 不结算
       记录 WARN: "[CardEffectEngine] Trigger chain depth exceeded: max=10, root=<ID>, chain=<A→B→...→K>"
       continue（跳过该效果——队列中剩余效果继续结算）
  3. if card_instance_id in visited_card_ids:
       effect 不结算（循环检测——同一卡牌不重复触发）
       记录 DEBUG 日志
       continue
  4. visited_card_ids[card_instance_id] = true
  5. _resolve(effect_instance) → 可能产生新效果 → 中分辨率插入队列
  6. 出栈下一个效果（递归直到栈为空）
```

**扇出分支共享深度计数器**：如果效果 A 同时触发 B1 和 B2（扇出）→ B1 和 B2 都在深度+1 层。两者共享同一个深度计数器——总节点数（非最深分支）达到 11 即截断。

### 信号路由（ADR-0007 合规）

| 信号 | 分类 | 发射者 | 载荷 | 订阅者 |
|------|------|--------|------|--------|
| `effect_registered` | Cat 2b | CardEffectEngine | `{card_instance_id, effect_ids: Array[int], target_id}` | CombatUI（角色绑定图标更新）、StatusSystem（新效果若产生状态则注册） |
| `effect_removed` | Cat 2b | CardEffectEngine | `{card_instance_id, effect_ids: Array[int], target_id, reason}` | CombatUI（图标清除）、StatusSystem（状态清理） |
| `effect_suspended` | Cat 2b | CardEffectEngine | `{card_instance_id, effect_ids: Array[int], reason: "character_off_field"}` | CombatUI（图标灰显） |
| `effect_restored` | Cat 2b | CardEffectEngine | `{card_instance_id, effect_ids: Array[int]}` | CombatUI（图标恢复） |
| `stack_overflow_warning` | Cat 2b | CardEffectEngine | `{root_card_id, depth: int, chain: Array[int]}` | DebugOverlay、CombatUI（可选——开发模式显示溢出指示器） |

**不通过信号传播的内容**：
- **效果产生的状态变更** → StatusSystem 直接调用（`apply_status()` / `remove_status()`），StatusSystem 内部通过 GSM Cat 1 信号传播属性变更
- **效果产生的伤害/治疗** → 直接返回给 CombatSystem 调用方（同步结算），CombatSystem 通过 GSM Cat 2b 信号通知 CombatUI 更新 HP
- **效果引擎不发射 Cat 1 信号**——引擎不写入 GSM，因此不产生 GSM 状态变更信号

### 子系统集成契约

```
CardEffectEngine 的子系统调用方向（读取 vs 写入）：

读取（只读——不修改被调用方的状态）：
  CardSystem.get_template(template_id) → CardTemplate
    # 查询卡牌模板的效果字段——O(1) 字典查询
  CardSystem.get_instance(card_instance_id) → CardInstance
    # 查询卡牌实例的运行时状态（等级、铭刻）
  GSM.player.* / GSM.battle.* / GSM.narrative.*
    # 第一层只读访问——当前境界、回合数、运行种子、story_flags
  BindingSystem.get_binding_multiplier(card_instance_id) → float
    # 查询预计算的本命加成乘数（1.0 或 1.5）——不绑定时不查询
  StatusSystem.get_active_statuses(target_id) → Array[StatusEffect]
    # 查询目标身上的活跃状态——用于条件判定和免疫检查

写入（通过子系统接口间接写入——不直接调用 GSM）：
  StatusSystem.apply_status(target_id, template) → ApplyResult
    # 施加状态——StatusSystem 内部写入 GSM.battle.temp_effects
  StatusSystem.remove_status(status_id) → bool
    # 移除状态——StatusSystem 内部从 GSM 清理
  StatusSystem.remove_statuses_by_source(target_id, source_id) → int
    # 批量移除（覆盖绑定/角色阵亡/效果失效场景）
  CombatSystem.damage_target(target_id, amount, element) → DamageResult
    # 伤害/治疗通过 CombatSystem（同步结算——CombatSystem 更新 HP 并写 GSM）
  EventSystem.set_flag(flag, value) → void
    # SET_FLAG 效果类型委托 EventSystem 写入 story_flags
  CostSystem.modify_temporary_cost(amount: int) → void
    # 费用修改效果（丹药临时费用加成/减成）

不调用的系统：
  GameStateManager（写入）——效果引擎只读 GSM，不写入
  FormationSystem（阵法触发）——阵法激活由 CombatSystem 在 Phase 2 编排
  SaveLoadSystem——效果引擎不触发存档
  SceneManager——效果引擎不触发场景切换
```

### PRD 伪随机分布引擎

```
PRDEngine 内部类（CardEffectEngine 持有单例）：

  状态：
    var prng := RandomNumberGenerator.new()  # 独立 RNG 实例（不共享全局状态）
    # 初始化时：prng.seed = GsM.meta.seed

  算法：
    P_base ∈ {0.05, 0.10, 0.15, ..., 0.95}  # 5% 步进
    C: float（调优参数——控制收敛速度，默认待游戏测试校准）
    P_current[card_instance_id] = P_base     # 每卡牌实例独立的状态

  next_random(card_instance_id, p_base) → bool:
    if GsM.meta.prng_override_seed != null:  # 测试模式
      var test_prng := RandomNumberGenerator.new()
      test_prng.seed = prng_override_seed
      roll = test_prng.randf()
    else:
      roll = prng.randf()                    # 使用实例 RNG [0.0, 1.0)
    if roll < P_current[card_instance_id]:
      P_current[card_instance_id] = P_base   # 触发——重置
      return true
    else:
      P_current[card_instance_id] += P_base × C  # 失败——累加概率
      if failure_streak >= ceil(1/P_base):      # 怜悯保护
        P_current[card_instance_id] = P_base
        return true
      return false

reset_prng_seed(seed: int) → void:
  # 测试模式：设置确定性种子——所有 randf() 调用可重现
```

**为什么 PRD 不是全局单例**：`P_current` 状态按 `card_instance_id` 独立追踪——不同卡牌的"30% 概率"不共享失败计数。玩家打出一张"30% 冰冻"失败后，下一次同卡牌的 P_current 累加——但另一张"30% 眩晕"从独立的 P_base 开始。

### AI 评估接口

```
# 不可变快照（评估期间不触碰游戏状态）
create_evaluation_snapshot() → GameStateSnapshot:
  # 浅拷贝当前机制数据——角色、状态、绑定、阵法、GSM 快照
  # 不含动画/UI/音效/VFX 数据
  # 单次 AI 回合只创建一次——所有评估共用

# 核心评估
evaluate_effect(card_id, target_id, snapshot) → EffectEvaluation:
  # 纯计算——不修改任何状态
  # 返回：{damage, healing, stat_changes: Dictionary, statuses_applied: Array, 
  #         is_overkill: bool, is_overheal: bool}

evaluate_effect_probabilistic(card_id, target_id, snapshot) → Array[ProbabilityOutcome]:
  # 含 RNG 效果的完整概率分布
  # 每项：{outcome: EffectEvaluation, probability: float}

simulate_chain(card_id, target_id, snapshot, max_depth=10) → ChainPreview:
  # 模拟打出此卡后的完整触发链（含概率）
  # 返回：{chain: [{step, source, effect, probability}], would_overflow: bool}

get_effect_categories(card_id) → Array[EffectCategory]:
  # 效果类型标签：DAMAGE, HEAL, BUFF, DEBUFF, CONTROL, DRAW, BIND, FORMATION, UNEVALUABLE
  # UNEVALUABLE = 依赖隐藏信息的效果（如偷牌）——AI 使用模板 base_weight 作后备

性能预算：
  evaluate_effect() 单次 <100μs（纯计算——无信号/无对象分配）
  simulate_chain() 深度 5 <500μs
  AI 回合总评估：288 次 × 100μs ≈ 29ms（跨帧分摊）
  快照创建：1-2ms（一次性成本——单次 AI 回合只创建一次）
```

### 对象生命周期与 Autoload 初始化

```
CardEffectEngine 初始化顺序（Autoload #10）：
  前提：GSM / InputManager / SceneManager / SaveLoad / EventSystem / CardSystem / CostSystem / StatusEffectSystem / CombatSystem 已就绪

  # 修正后的 Autoload 顺序（综合 ADR-0001/0004/0005/0002/0003/0006/0008）：
  # #1  GSM              (Foundation, ADR-0001)
  # #2  InputManager      (Foundation, ADR-0004)
  # #3  SceneManager      (Foundation, ADR-0005)
  # #4  SaveLoad           (Foundation, ADR-0002)
  # #5  EventSystem        (Foundation, ADR-0003)
  # #6  CardSystem         (Core, ADR-0006)
  # #7  CostSystem         (Core, ADR-0015)
  # #8  StatusEffectSystem (Core, ADR-0011)
  # #9  CombatSystem       (Feature, ADR-0008)
  # #10 CardEffectEngine   (Feature, ADR-0009)

_ready():
  1. 等待 gsm_initialized 信号（ADR-0001）——确保 GSM 可读
  2. Godot 按 Autoload 顺序同步调用所有 `_ready()`——CardEffectEngine 的 `_ready()` 执行时，
     CombatSystem 的 `_ready()` 已完成，`resolve_phase_effects()` API 可调用
  3. 初始化效果模板注册表（由 CardEffectEngine 负责——非 EffectFactory，工厂不持有注册表）：
     a. CardEffectEngine 扫描 assets/cards/effects/ 目录
     b. 加载所有 .tres EffectTemplate Resource
     c. 注册到 Dictionary[StringName, EffectTemplate] templates
     d. 发射 effect_templates_loaded 信号（Cat 2b——CardSystem 可能等待此信号以验证效果引用完整性）
  4. 初始化 PRDEngine——从 GSM.meta.seed 获取 PRNG 种子
     var prng := RandomNumberGenerator.new()
     prng.seed = GsM.meta.seed  # 或测试覆盖种子 prng_override_seed
  5. 战斗阶段触发由 CombatSystem 直接调用 `CardEffectEngine.resolve_phase_effects(phase)`（编排器→子系统——引擎不订阅 CombatSystem 信号）

运行时状态（不持久化）：
  _active_effects: Dictionary[int, Array[EffectInstance]]
    # key = card_instance_id → 该卡牌产生的所有活跃效果实例
  _effect_by_id: Dictionary[int, EffectInstance]
    # key = effect_instance_id（全局唯一递增）→ 效果实例（用于 remove/suspend 快速查找）
  _resolution_stack: ResolutionStack
    # 当前正在结算的效果队列——战斗阶段结束时必须为空
```

## 考虑的替代方案

### 替代方案 A：纯 Dictionary/Array 动态类型（无类层级）

- **描述**：所有效果实例使用 `Dictionary` 存储字段（`{"type": "damage", "base_value": 3, ...}`），通过 `match type:` 分支处理结算逻辑。与状态效果系统的 `metadata: Dictionary` 扩展数据模式一致。
- **优点**：零内存开销（无 `RefCounted` 对象分配）、不需要维护类层级、策划可以通过 JSON/CSV 编辑效果数据（而非 `.tres` Resource）、与 Godot 4.5 的类型化数组兼容性更好（`Array[Dictionary]` 比 `Array[RefCounted]` 更简单）
- **缺点**：无编译时类型安全——`match` 分支遗漏不会在编译时捕获（需 100% 测试覆盖）；`Dictionary.get("base_value", 0)` 的字符串键容易拼写错误；无法使用 `@abstract` 虚函数派发（`match` 链的性能随效果类型增长而线性增加）；Inspector 编辑支持弱（策划无法在 Godot 编辑器中直接编辑 Dictionary 字段）
- **拒绝原因**：GDD 开放问题 #1 已明确排除了此选项——"纯数据配置在 MVP 中可行，但 Resource + RefCounted 提供类型安全和 Inspector 编辑体验"。222 张卡牌的效果数量足以证明编译时类型安全的价值。Godot 4.5 `@abstract` 的性能优势（虚函数调用 O(1) vs match 链 O(n)）在大量效果结算时具有意义。

### 替代方案 B：每效果类型独立 Resource 子类（无 RefCounted 运行时层）

- **描述**：每个效果直接实例化为 Resource 子类（`DamageEffectResource`、`HealEffectResource` 等）——Resource 同时承担模板和运行时实例的双重角色。卡牌打出时从模板克隆一份 Resource 作为运行时副本。
- **优点**：单一对象模型（策划和程序员用同一套类）、无需工厂模式、Resource 的 `.duplicate()` 支持子资源深拷贝
- **缺点**：Resource 比 RefCounted 重——额外的引用计数、资源路径、`resource_name` 字段；`.duplicate()` 在嵌套 Resource 上的性能开销（深拷贝所有 `@export` 字段）；克隆的 Resource 仍持有原始模板的共享子资源引用——修改克隆可能污染模板（Godot Resource 共享语义的根本限制——与 ADR-0002 的禁止模式一致）；无法区分"模板定义"和"运行时状态"（导致编辑器中卡牌模板被运行时数据污染）
- **拒绝原因**：违反"模板只读 + 实例可变"的核心约束。Godot Resource 的共享引用语义（修改一处污染所有引用者）正是 ADR-0006 禁止写入 CardTemplate 的原因——效果引擎不应重蹈此错误模式。RefCounted 没有 Resource 的路径和引用语义包袱——更轻量，且天然防止模板污染。

### 替代方案 C：效果引擎作为 CombatSystem 内部模块（非独立 Autoload）

- **描述**：效果解析和结算逻辑作为 `CombatSystem` 的内部类或子节点实现——不创建单独的 `CardEffectEngine` Autoload。
- **优点**：减少 Autoload 数量（项目已有 7+）；效果引擎与战斗系统的耦合天然紧密——不需要跨 Autoload 信号通信；初始化顺序简化
- **缺点**：AI 系统需要 `evaluate_effect()` 在战斗外可用（AI 思考和模拟不依赖战斗实例）——CombatSystem 内部模块无法提供此独立性；事件系统（ADR-0003）的 `TRIGGER_EFFECT` Outcome 可能需要在非战斗场景触发效果；单元测试覆盖——效果引擎独立时可以直接注入模拟对象，内部模块则需要完整的 CombatSystem 实例；违反单一职责原则——CombatSystem 已有 9 个子系统编排职责（ADR-0008），增加效果栈管理使其过于庞大
- **拒绝原因**：AI 评估接口的独立性要求是决定性的——`create_evaluation_snapshot()` 和 `evaluate_effect()` 必须在战斗上下文外可用。事件系统的效果触发（战斗外事件可能产生状态变更）也需要效果引擎独立存在。独立 Autoload 支持在不启动完整战斗的情况下进行效果系统的单元测试和回归测试。

### 替代方案 D：效果引擎作为非 Autoload 服务类（由 CombatSystem 和 AI 实例化）

- **描述**：`CardEffectEngine` 实现为普通 GDScript 类（不注册为 Autoload）——CombatSystem 在战斗开始时创建一个实例（用于运行时效果结算），AI 系统在 AI 回合开始时创建另一个实例（用于干跑评估）。两个实例共享相同的代码但拥有独立的状态。
- **优点**：完全避免 Autoload 数量增加（保持 7 个）；AI 评估与战斗结算天然隔离（不同实例——无状态共享风险）；初始化顺序无关（不参与 Autoload 链）；未来可通过引擎实例池扩展多场并行模拟（如预测 N 回合后的局面）
- **缺点**：EffectTemplate 注册表（222 个 Resource）需要在两个实例间共享——要么通过静态类变量（违反 Autoload 封装），要么通过 CombatSystem 在创建引擎实例时注入模板注册表引用（增加 CombatSystem 的职责）；多个消费者（StatusSystem、BindingSystem、FormationSystem 可能需要在战斗外查询效果数据）需要一个中央访问点——无 Autoload 时需要 CombatSystem 暴露 getter 间接访问；调试困难——多实例使得"谁在什么时候创建了什么效果"的追踪变复杂
- **拒绝原因**：模板注册表共享问题是根本性的——222 个 `EffectTemplate` Resource 必须在一个位置加载一次，而非每个实例都重新加载（浪费内存和加载时间）。Autoload 提供了自然的单例注册表（加载一次，全局访问）。AI 评估所需的隔离性可以通过 `GameStateSnapshot` 不可变快照在 Autoload 模式中实现——无需独立实例。权衡判断：+1 Autoload 的初始化顺序负担 < 多实例的内存/同步复杂度

## 后果

### 积极的

- **效果解析的一致性**：222 张卡牌的所有效果通过同一个 `ResolutionStack` 结算——优先级规则、触发链限制、PRD 逻辑集中管理，无分散在不同系统中的隐藏行为
- **AI 评估的精确性**：干跑评估接口（`evaluate_effect` + `simulate_chain`）在不触碰游戏状态的前提下提供完全的确定性预测——AI 可以精确比较候选卡牌的效果差异，做出最优决策
- **模板/实例分离的正确性**：拒绝替代方案 B（纯 Resource），选择 Resource + RefCounted 模型——从根本上防止模板污染（与 ADR-0006 卡牌数据模型的约束一致）
- **Godot 4.5 功能利用**：`@abstract` 虚函数派发比 `match`/`if` 链更高效（O(1) vs O(n)，在 222 卡牌×多效果的结算场景中具有实际性能意义）；类型化 `Array[EffectInstance]` 提供编译时类型安全
- **事件系统词汇表统一**：扩展 ADR-0003 的 `OutcomeType` 枚举（而非创建重复）——消除 OQ-05 的词汇表分歧。`SET_FLAG` 效果类型委托 EventSystem 写入——保持 Foundation 层 `story_flags` 的单一写入者契约
- **可测试性**：独立 Autoload 允许不启动完整战斗流程的单元测试——`ResolutionStack` 的优先级排序、触发链截断、PRD 确定性均可单独验证

### 消极的

- **Autoload 数量增加**：项目预计从 9 个 Autoload 增加到 10 个（+CardEffectEngine）——初始化顺序链更长（见 §对象生命周期 修正后的完整顺序），故障排查时需检查更多模块
- **对象分配开销**：每个卡牌打出创建 1-N 个 `RefCounted` EffectInstance 对象——Godot 的引用计数 GC 在每帧创建 50+ 实例时可能产生微抖动。缓解措施：对象池（`EffectInstancePool`）复用频繁创建的效果类型
- **双层模型的复杂性**：程序员在代码中处理两个类层级（`EffectTemplate` Resource + `EffectInstance` RefCounted）——需要 `EffectFactory` 桥梁。策划在 Inspector 中编辑 Resource，但运行时调试需检查 RefCounted 实例
- **PRD 状态的不可见性**：`P_current` 按 `card_instance_id` 追踪——玩家无法直接看到"30% 概率"当前的内部累加值。这可能导致困惑："为什么这次触发了而上一次没触发？"——通过 CombatUI 的可选 PRD 指示器缓解（显示"30% (×4 未触发)"提示）
- **帧预算风险**：最坏场景——6 个敌人各打出 2 张卡牌（12 个效果）+ 3 个阵法 + 10 个活跃状态触发 = ~25 个效果进入 ResolutionStack。每个效果的 `_resolve()` 包含优先级比较 + 触发链检查 + 虚函数调用——需要在目标硬件上验证 <2ms 预算

### 风险

- **Godot 4.5 `@abstract` 稳定性**：`@abstract` 类在 Godot 4.5 中引入——可能存在未发现的边缘情况（如 `@abstract` 类在 `preload()` 循环引用下的行为、`@abstract` 虚函数与 `Callable.bind()` 的交互）。缓解措施：在引擎参考验证中优先测试——若发现阻塞问题，退回到基类 + `assert(false, "must override")` 守门模式（替代方案 A 的运行时检查版本）
- **RefCounted GC 抖动**：Godot 4.5 优化了引用计数性能，但每帧 50+ `RefCounted` 创建/销毁的实际表现需在 60fps 目标下验证。缓解措施：对象池预分配 + 目标硬件上的性能测试
- **触发链的不可预测性**：复杂效果交互（A 触发 B → B 触发 C → C 修改 A 的优先级）可能导致非直觉的结算顺序——即使符合规则。GDD 已定义优先级规则但玩家可能不理解"为什么我的效果在那个时候触发了"。缓解措施：战斗日志的可选详细模式——列出每次结算的优先级依据
- **PRD 种子同步**：如果 `GsM.meta.seed` 在战斗中途因存档读档而改变——PRD 的内部状态 `P_current` 需重置（存档不保存概率累加值——"读档后重新掷骰"）。确保重播和回归测试中种子一致性。缓解措施：存档时仅保存 `meta.seed`，不保存 `P_current` 字典——读档后所有 PRD 状态从 P_base 重新开始
- **Autoload 扩容**：8 个 Autoload 增加了初始化顺序脆弱性——单次 init-order 错误可能导致难以诊断的启动崩溃。缓解措施：编写自动化初始化顺序验证测试（`test_autoload_order.gd`）——在 CI 中阻止顺序偏差
- **StatusSystem 接口已确认**：本 ADR 定义的 StatusSystem API（`apply_status`、`remove_status`、`get_active_statuses`、`get_accumulated_value`、`remove_statuses_by_source`）已在 ADR-0011（状态效果系统，Accepted）中正式定义——接口签名详见 ADR-0011 §与 ADR-0009 的接口映射。两者保持一致，无需同步更新。
- **EffectTemplate 资产管线缺口**：222 个 EffectTemplate `.tres` 文件需要创作。本 ADR 未指定创作工作流（手动 Godot Inspector？CSV 导入工具？编辑器内插件？）——这是一个必须在编码前解决的生产风险。缓解措施：编码前独立决策中解决——MVP 可使用脚本驱动的 CSV→`.tres` 批量导出。

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| card-effect-engine.md | §1 效果类型体系——4 大类覆盖 222 张卡牌 | Resource 子类（`EffectTemplate`）+ RefCounted 子类层级（`InstantEffect` / `PersistentEffect` / `TriggeredEffect` / `ReplacementEffect`）——编译时类型安全保证每种效果的正确结算路径 |
| card-effect-engine.md | §3 效果结算顺序——5 级优先级 + 中分辨率插入 | `ResolutionStack` 的优先级排序（主动出牌 > 先发己方 > 普通己方 > 敌方 > instance_id）+ `_resolve_stack()` 的 LIFO 出栈 + 队列中分辨率插入新效果 |
| card-effect-engine.md | §8 效果描述规范化——描述模板与数据双向绑定 | `EffectTemplate.description_tmpl` 字段存储描述模板——自动生成器在效果数值变更时同步更新（未来功能——MVP 中描述为手写字符串） |
| card-effect-engine.md | §9 概率效果 PRD——5% 步进 + 怜悯保护 | `PRDEngine` 内部类——`next_random()` 实现累加概率 + 连续失败 `ceil(1/P_base)` 次后强制触发 |
| card-effect-engine.md | §10 AI 评估接口——干跑评估 + 触发链模拟 | `evaluate_effect()` / `simulate_chain()` / `GameStateSnapshot`——在不可变快照上执行纯计算，不修改游戏状态 |
| card-effect-engine.md | §触发链管理——深度 10 层 + 循环检测 | `visited_card_ids: Dictionary`（`Dictionary[int, bool]`——GDScript 4.x 无 `Set` 类型，字典键 O(1) 查找）+ `current_depth` 计数器——第 11 层截断 + WARN 日志 |
| combat-system.md | 阶段触发——Phase 0/1/2/3/4/5/6 效果结算 | CombatSystem 在 `advance_phase()` 中直接调用 `CardEffectEngine.resolve_phase_effects(phase)`——编排器→子系统调用，每阶段收集并结算该阶段应触发的效果 |
| status-system.md | §6 接口规范——施加/移除/查询状态 | `StatusSystem.apply_status()` / `remove_status()` / `get_active_statuses()` / `get_accumulated_value()`——效果引擎通过这些接口与状态系统交互 |
| binding-system.md | §3 本命加成——native_multiplier 预计算锁定 | `BindingSystem.get_binding_multiplier(card_instance_id) → float`——效果引擎查询预计算的乘数（1.0 或 1.5），不运行时重查 |
| ADR-0003 event-system | OutcomeType 枚举为共享词汇表（OQ-05） | 本 ADR 扩展 ADR-0003 的枚举——新增 5 种效果专属类型（`APPLY_STATUS`、`MODIFY_STAT`、`TRIGGER_CHAIN`、`ACTIVATE_FORMATION`、`MODIFY_COST`），非重复创建 |

## 性能影响
- **CPU**：单次 `resolve_card()`（栈结算 + 触发链）< 2ms（Godot profiler 验证）。AI 评估总预算 ~30ms——跨帧分摊（每帧评估 96 个候选，3 帧完成全部 288 次）。`ResolutionStack` 的优先级排序使用 Godot 内置 `Array.sort_custom()`——100 元素 <0.1ms
- **内存**：每个 `EffectInstance` RefCounted 对象 ~200 bytes × 最多 50 活跃实例/角色 × 6 角色 = ~60KB 活跃效果内存。`EffectTemplate` Resource 在磁盘上 ~500 bytes-2KB/模板 × 222 卡牌 = 约 100-400KB 磁盘占用（`.tres` 文本格式）
- **加载时间**：222 个 `EffectTemplate` Resource 的加载策略与 CardSystem 模板一致——同步加载（`ResourceLoader.load()` 在主线程），预计 <200ms（与 ADR-0006 的 222 个 CardTemplate 加载共享启动画面时间窗口）；若超过则切换到 `ResourceLoader.load_threaded_request()` 异步加载
- **网络**：不适用（单人游戏）

## 迁移计划
不适用——这是新系统的初始架构决策。无现有效果系统需要迁移。

若未来需要从纯 Dictionary 原型（原型阶段可能使用）迁移到 Resource+RefCounted 模型：
1. 创建 `EffectTemplate` Resource 类，定义所有 `@export` 字段
2. 编写脚本将原型中的 JSON/Dictionary 效果数据批量导出为 `.tres` 文件
3. 更新 `CardTemplate` 的 `effect_template_ids` 引用从字符串ID改为 Resource UID
4. 废弃运行时的 Dictionary 效果实例——切换为 `EffectFactory.create_instance()`

## 验证标准
- 10 张代表性卡牌（覆盖即时/持续/触发式/替代 + 各稀有度）的效果从打出到结算完毕的正确行为
- ResolutionStack 的 5 级优先级排序——"先发效果在普通效果之前结算"验收测试
- 触发链深度 = 10 层正常结算，深度 = 11 层截断 + WARN 日志
- PRD "30% 概率"在 100 次试验中触发 24-36 次（99% CI）+ 连续失败 4 次后第 5 次强制触发
- `evaluate_effect()` 与 `resolve_card()` 在同一输入下的结果完全一致（确定性预测）
- 帧预算：Phase 0 全效果 tick（6 角色 + 3 阵法 + 10 buff）< 2ms

## 相关决策
- ADR-0001（GSM——效果引擎的只读上下文和状态传播路径）
- ADR-0006（CardSystem——Template/Instance 分离模式 + 实例工厂）
- ADR-0003（EventSystem——OutcomeType 共享词汇表 + SET_FLAG 委托写入）
- ADR-0004（InputManager——战斗动画期间通过 ANIMATION 锁栈阻止输入）
- ADR-0005（SceneManager——战斗场景加载和退出）
- ADR-0007（信号分类——效果生命周期信号归类为 Cat 2b）
- ADR-0008（CombatSystem——7 阶段触发时机 + 效果结算入口 + `phase_changed(old_phase, new_phase, turn)` 信号）
- ADR-0011（状态效果系统——status-system.md 的接口已在 ADR-0011 中规定——接口映射详见 ADR-0011 §与 ADR-0009 的接口映射）