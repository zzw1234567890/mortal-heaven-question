# ADR-0019：资源系统 — Core 层 Autoload 公式服务 + GSM 数据存储分离

## 状态
Accepted（2026-07-26——Core 层审查通过。修复：Autoload 计数统一为 25、过时引用 ADR-0017 移除。）

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Core / Resource |
| **知识风险** | LOW（仅使用 Dictionary、Signal、Autoload、纯数学公式——全部自 4.0 起稳定） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **使用的截止后 API** | None——所有 API 自 Godot 4.0 起稳定 |
| **需要验证** | `const Dictionary` 中的拆解基础值表不被运行时意外修改（GDScript `const` 不冻结嵌套内容——与 ADR-0010 相同风险） |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`player.resources` 域数据存储、`batch_updated` 信号传播资源变更）；ADR-0007（三分类信号体系——资源变更通过 GSM Cat 1 `batch_updated` 传播，ResourceSystem 不发射自有数据信号） |
| **启用** | 商店系统（购买/出售灵石消耗）、卡组编辑系统（删卡费用 `delete_card_cost()`、拆解价值 `dismantle_value()`）、炼丹炼器系统（灵材消耗）、法宝铭刻系统（灵材+灵石双重消耗）、探索系统（地图通关灵石奖励、境界差额惩罚 `realm_gap_penalty()`）、战斗系统（战利品灵石奖励） |
| **阻塞** | 商店 Epic、卡组编辑 Epic、炼丹炼器 Epic、法宝铭刻 Epic——在上述系统实现消费逻辑前必须接受本 ADR |
| **排序说明** | Core 层中期 ADR。在 GSM（ADR-0001）和 RealmSystem（ADR-0010——资源公式引用境界数据）之后被接受。在商店/卡组编辑/炼丹炼器 ADR 之前被接受 |

## 上下文

### 问题陈述

`resource-system.md` GDD 定义了两种核心经济资源（灵石+灵材）和 7 条关键公式（拆解价值、删卡费用、灵材出售、境界差额惩罚、余额校验、身份加成、炼制物折价）。GSM（ADR-0001）已声明 `player.resources` 域的数据所有权，并提供了 `add_resource(type, amount)` 和 `spend_resource` 作为第二层原子写入入口。

但以下架构问题仍未解决：

1. **公式归属缺失**：7 条资源公式目前仅存在于 GDD 中——没有代码层面的单一真理来源。如果战斗系统、探索系统、卡组编辑系统各自实现拆解公式或境界差额惩罚，将产生公式不一致的 bug（如 ADP-0012 审计警告 W-C4 的同类问题——cross-GDD 重复定义）
2. **API 不完整**：GSM 的 `add_resource` 不处理灵材品质参数（灵材按低/中/高/顶四级品质存储为 `player.resources.ling_cai.{low,medium,high,top}`），调用方需自行理解内部结构——违反封装原则
3. **消费校验分散**：删卡费用、灵材消耗、灵石消费的余额校验逻辑分散在各调用方——如果某系统忘记调用 `can_spend()` 直接操作余额，将产生负数资源
4. **资源变更信号不统一**：各系统应直接发射 `resource_changed` 还是通过 GSM `batch_updated` 传播？ADR-0007 已确立 Cat 1（GSM 数据变更信号）的规范——但资源系统需明确执行这一契约

需要的是一个**集中的公式服务层**——拥有所有资源公式，提供类型安全的读写 API，强制余额校验，并通过 GSM 统一传播资源变更信号。

### 约束

- **GSM 数据所有权不变**：`player.resources.ling_shi` 和 `player.resources.ling_cai.{low,medium,high,top}` 的所有权仍在 GSM——ResourceSystem 不持有数据副本
- **Autoload 槽位**：ResourceSystem 为 Autoload #16——仅依赖 GSM（#1），初始化依赖链极简。完整链 25 个见 `production/session-state/active.md` Autoload 全链
- **Godot 4.6 惯用性**：使用 GDScript Autoload 模式 + const Dictionary 公式表——与 ADR-0010（RealmSystem）一致的架构模式
- **所有消费必须先校验**：GDD §4 `can_spend()` 是所有消费操作的唯一前置入口——ResourceSystem 强制执行此契约
- **公式为纯函数**：所有资源公式无副作用——输入参数 → 返回数值。不修改 GSM 状态，不发射信号

### 需求

- 7 条资源公式的单一真理来源——杜绝跨系统重复定义
- 类型安全的灵材品质接口——调用方传入 `LingCaiQuality` 枚举而非裸 int
- 余额校验的强制入口——所有消费操作必须通过 `can_spend()` → `spend_resource()`
- 资源变更统一通过 GSM `batch_updated`（Cat 1）传播——ResourceSystem 不发射自有数据信号
- 拆解公式独立于卡牌系统——卡组编辑系统调用 `ResourceSystem.dismantle_value()` 获取价值后自行执行拆解流程

## 决策

**ResourceSystem 作为 Core 层 Autoload 实现——持有 7 条资源公式（const 数据表 + 纯函数）和类型安全的读写 API（add/spend/can_spend/get），但不持有任何资源数据。所有数据存储在 GSM `player.resources` 域中，所有资源变更通过 GSM 第二层原子方法写入并触发 `batch_updated`（Cat 1）信号传播。**

### 层分类决议：Core 层论证

ResourceSystem 被 8+ 个下游系统消费（商店、卡组编辑、炼丹炼器、法宝铭刻、战斗、探索、事件、身份选择），自身无运行时可变状态——公式表为编译时常量。这符合 Core 层的"基础设施"定义（与 CardSystem 的只读模板注册表和 RealmSystem 的静态数据表角色一致），而非 Feature 层的"垂直功能"定义。

### 架构图

```
┌──────────────────────────────────────────────────────────────┐
│                    GSM (ADR-0001)                             │
│  player.resources.ling_shi: int                               │
│  player.resources.ling_cai.{low, medium, high, top}: int      │
│  _set_resource_ling_shi(value) → void  (原子写入 + batch_updated)│
│  _set_resource_ling_cai(quality, value) → void                │
│  batch_updated(changes) → Cat 1 信号                          │
└──────────────┬───────────────────────────────────────────────┘
               │ 数据存储所有权
               ▼
┌──────────────────────────────────────────────────────────────┐
│              ResourceSystem (ADR-0019) — Autoload             │
│                                                               │
│  ┌─ 公式表（const，编译时常量）─────────────────────┐         │
│  │ DISMANTLE_BASE = [10, 30, 100, 400, 2000]        │         │
│  │ LING_CAI_SELL_PRICE = [10, 30, 80, 200]          │         │
│  │ DELETE_CARD_BASE = 50; DELETE_CARD_INCREMENT = 25 │         │
│  │ CRAFTED_DISMANTLE_RATIO = 0.5                    │         │
│  │ REALM_GAP_STEP = 0.3; REALM_GAP_FLOOR = 0.1      │         │
│  └──────────────────────────────────────────────────┘         │
│                                                               │
│  ┌─ 读写 API（类型安全包装层）─────────────────────┐         │
│  │ add_resource(type, amount, quality?) → bool      │         │
│  │ spend_resource(type, amount, quality?) → bool    │         │
│  │ can_spend(type, amount, quality?) → bool         │         │
│  │ get_resource(type, quality?) → int               │         │
│  └──────────────────────────────────────────────────┘         │
│                                                               │
│  ┌─ 公式 API（纯函数，无副作用）───────────────────┐         │
│  │ dismantle_value(rarity, level) → int             │         │
│  │ dismantle_crafted_value(rarity, level) → int     │         │
│  │ delete_card_cost(delete_count) → int             │         │
│  │ sell_ling_cai_value(quality, qty) → int          │         │
│  │ realm_gap_penalty(player_L, map_max_L) → float   │         │
│  │ apply_ling_shi_bonus(base, multiplier) → int     │         │
│  └──────────────────────────────────────────────────┘         │
└──────────────┬──────────────────────────────────────────────┘
               │ add_resource / spend_resource / get_resource / 公式
               ▼
   ┌───────────┬──────────┬──────────┬──────────┬──────────┐
   │ 商店系统  │卡组编辑  │炼丹炼器  │法宝铭刻  │探索系统  │
   │(购买/出售)│(删卡/拆解)│(灵材消耗)│(双重消耗)│(通关奖励)│
   └───────────┴──────────┴──────────┴──────────┴──────────┘
   ┌───────────┬──────────┬──────────┐
   │ 战斗系统  │事件系统  │身份选择  │
   │(战利品)   │(事件奖励)│(初始灵石)│
   └───────────┴──────────┴──────────┘
```

### 关键接口

```gdscript
# === ResourceSystem Autoload ===

## 灵材品质枚举
enum LingCaiQuality { LOW = 1, MEDIUM = 2, HIGH = 3, TOP = 4 }

# === 读写 API（类型安全包装——内部委托 GSM 第二层原子写入）===

## 增加资源。返回 false 表示无效 type/quality。
## 灵石：ResourceSystem.add_resource(&"ling_shi", 100)
## 灵材：ResourceSystem.add_resource(&"ling_cai", 3, LingCaiQuality.LOW)
func add_resource(type: StringName, amount: int, quality: int = -1) -> bool:
    match type:
        &"ling_shi":
            var new_val: int = GSM.player.resources.ling_shi + amount
            GSM._set_resource_ling_shi(new_val)
            return true
        &"ling_cai":
            if quality < 1 or quality > 4: return false
            var key: String = _quality_key(quality)
            var current: int = GSM.player.resources.ling_cai[key]
            GSM._set_resource_ling_cai(quality, current + amount)
            return true
    return false

## 消费资源。余额不足返回 false，资源不变。
func spend_resource(type: StringName, amount: int, quality: int = -1) -> bool:
    if not can_spend(type, amount, quality): return false
    match type:
        &"ling_shi":
            GSM._set_resource_ling_shi(GSM.player.resources.ling_shi - amount)
            return true
        &"ling_cai":
            var current := _get_ling_cai_by_quality(quality)
            GSM._set_resource_ling_cai(quality, current - amount)
            return true
    return false

## 余额校验——所有消费操作的前置入口
func can_spend(type: StringName, amount: int, quality: int = -1) -> bool:
    return get_resource(type, quality) >= amount

## 查询资源数量
func get_resource(type: StringName, quality: int = -1) -> int:
    match type:
        &"ling_shi": return GSM.player.resources.ling_shi
        &"ling_cai": return _get_ling_cai_by_quality(quality) if quality >= 1 else \
            GSM.player.resources.ling_cai.low + GSM.player.resources.ling_cai.medium + \
            GSM.player.resources.ling_cai.high + GSM.player.resources.ling_cai.top
    return 0

# === 公式 API（纯函数，不修改状态，不发射信号）===

## 拆解卡牌价值（未炼制卡牌）
func dismantle_value(rarity: int, level: int) -> int:
    const BASE := [10, 30, 100, 400, 2000]
    var base: int = BASE[rarity - 1] if rarity >= 1 and rarity <= 5 else 0
    var bonus: int = floori(base * maxi(0, level - 1) * 0.05)
    return base + bonus

## 炼制物拆解价值（折价 50%）
func dismantle_crafted_value(rarity: int, level: int) -> int:
    return floori(dismantle_value(rarity, level) * 0.5)

## 删卡费用——delete_count 为本局已删次数（首次=1）
func delete_card_cost(delete_count: int) -> int:
    return 50 + 25 * maxi(0, delete_count - 1)

## 出售灵材价值
func sell_ling_cai_value(quality: int, quantity: int) -> int:
    const PRICE := [10, 30, 80, 200]
    if quality < 1 or quality > 4: return 0
    return PRICE[quality - 1] * quantity

## 境界差额灵石惩罚——回旧地图收益递减（GDD 公式 7）
func realm_gap_penalty(player_L: int, map_max_L: int) -> float:
    var gap: int = player_L - map_max_L
    if gap <= 0: return 1.0
    return maxf(0.1, 1.0 - gap * 0.3)

## 身份天赋灵石加成
func apply_ling_shi_bonus(base_amount: int, multiplier: float) -> int:
    return floori(base_amount * multiplier)
```

### GSM 第二层扩展方法（ResourceSystem 专用）

ResourceSystem 通过以下 GSM 原子写入方法操作资源数据——遵循 ADR-0008（CombatSystem 定义 `_set_battle_phase` 等）和 ADR-0014（ExplorationSystem 定义 `set_exploration_*` 等）的先例：

```gdscript
# === GSM 第二层：资源专用原子写入（纳入 ADR-0001 第二层 API）===

GSM._set_resource_ling_shi(value: int) → void:
  # 写入 player.resources.ling_shi = value + 发射 batch_updated
  # value 不可为负——调用方（ResourceSystem）保证非负

GSM._set_resource_ling_cai(quality: int, value: int) → void:
  # 写入 player.resources.ling_cai[{low,medium,high,top}] = value + 发射 batch_updated
  # quality ∈ [1,4]；value 不可为负
```

**信号传播路径**：`ResourceSystem.spend_resource()` → `GSM._set_resource_ling_shi(new_val)` → `batch_updated({"player.resources.ling_shi": {old, new}})` → HUD 刷新 + 音效播放。ResourceSystem 自身不发射任何 Cat 2b 信号——资源变更是数据变更，天然属于 GSM Cat 1 的职责范围（ADR-0007 §三分类信号体系）。

### 资源变更契约

```
读取路径：消费者直接访问 GSM.player.resources.*（GSM 第一层）
写入路径：所有系统 → ResourceSystem.add_resource / spend_resource → GSM 第二层原子方法 → batch_updated 信号
禁止路径：任何系统绕过 ResourceSystem 直接操作 GSM.player.resources.*（禁止模式）
禁止路径：任何系统绕过 can_spend() 直接判断余额后调用 spend_resource（不强制——依赖代码审查）
```

## 考虑的替代方案

### 替代方案 A：嵌入 GSM——公式和逻辑全部在 GameStateManager 内部

- **描述**：`dismantle_value()`、`delete_card_cost()` 等作为 GSM 的方法。`add_resource` 直接处理灵材品质。不创建独立 Autoload。
- **优点**：减少 1 个 Autoload；资源数据和方法在同一对象中——概念简单
- **缺点**：GSM 膨胀为"上帝对象"——GSM 的职责是运行时状态仲裁，不是经济公式字典。7 条公式 + 灵材品质枚举 + 境界差额运算添加到 GSM 会使接口表面积急剧增长。违反 ADR-0001 的设计意图（GSM 是数据层，非逻辑层）。违反 ADR-0010 的先例——RealmSystem 不被嵌入 GSM，正是因为"设计数据表不应与状态仲裁器混合"
- **拒绝原因**：GSM 的三层 API 设计已明确其边界——数据读写仲裁。公式逻辑属于 Core 层服务。遵循 ADR-0010 的先例——将静态公式/数据表从 GSM 中分离到独立 Core Autoload

### 替代方案 B：纯静态工具类（class_name + RefCounted）——非 Autoload

- **描述**：`class_name ResourceService` 的 RefCounted 工具类。所有方法为 `static func`。消费者通过 `ResourceService.dismantle_value(...)` 直接调用静态方法。非 Autoload，不占用 Autoload 槽位。
- **优点**：极简——无 Autoload 注册、无 `_ready()` 初始化、无生命周期管理。最适合纯公式服务（无内部状态）的 Godot 惯用模式。可测试性更好——无需模拟 Autoload 环境
- **缺点**：`add_resource` / `spend_resource` 需要访问 GSM——静态方法通过 `GSM` Autoload 全局访问，技术上可行但依赖隐式全局。如果未来需要缓存计算结果或持有配置状态，重构成本高于 Autoload
- **评估**：此替代方案非常适合 ResourceSystem 的纯公式特性——它是无状态的。但 ResourceSystem 的 `add/spend/can_spend/get` 方法是 GSM 的**主动类型安全包装层**——调用方期望一个与 GSM 解耦的稳定 API 表面。静态工具类在语法上可行（`ResourceService.spend_resource(...)` vs `ResourceSystem.spend_resource(...)`），但 Autoload 提供了更清晰的"这是系统级服务"的语义标识。两者的运行时成本差异可忽略（Autoload 节点 ~0.5KB 常驻内存）。**若未来发现公式服务不需要 Autoload 的生命周期管理，迁移到静态工具类是低成本重构（静态方法不依赖实例状态）**

### 替代方案 C：公式分散到各消费系统——无集中公式服务

- **描述**：拆解公式在卡组编辑系统中、删卡费用在卡组编辑系统中、境界差额惩罚在探索系统中、灵材出售在商店系统中。各自维护，无集中公式层。
- **优点**：无额外模块——每个系统独立运行
- **缺点**：公式重复定义——如果拆解公式在卡组编辑和商店中都出现，修改时容易遗漏。策划调参需要找到所有定义点。与审计警告 W-C4（cross-GDD 重复定义）的本质问题一致——分散导致漂移
- **拒绝原因**：GDD 已明确 resource-system.md 是 7 条公式的**权威来源声明**（"本系统定义了以下公式，所有下游系统通过接口查询"）。分散违反 GDD 设计意图。单一真理来源是架构原则——本 ADR 落实此声明

## 后果

### 积极的

- **公式单一真理来源**：7 条公式在 ResourceSystem 中唯一定义——策划调参修改一处，所有消费者自动生效。杜绝 W-C4 类 cross-system 公式不一致
- **灵材品质类型安全**：`LingCaiQuality` 枚举替代裸 int——编译时检查，消除 quality=5 的运行时错误
- **余额校验集中**：`can_spend()` → `spend_resource()` 是唯一消费路径——调用方无法绕过余额检查直接扣减
- **与 ADR-0010 架构一致**：Core 层 Autoload + GSM 状态所有权分离 + const 数据表 + 纯查询 API——开发者学习一种模式即可理解两个系统
- **信号合规**：资源变更通过 GSM Cat 1 `batch_updated` 传播——与 InputManager 的锁状态传播模式一致（ADR-0007 禁止模式 #11：不重复 GSM 信号）

### 消极的

- **增加 1 个 Autoload（#16，总链 25 个）**：初始化链增长。但 ResourceSystem 仅依赖 GSM（#1）——初始化顺序简单，不增加依赖复杂度
- **间接性**：调用方需要同时了解 GSM（读裸数据）和 ResourceSystem（读写 API）——两个入口。缓解：文档明确"读用 GSM 第一层，写用 ResourceSystem API"
- **GSM 第二层方法膨胀**：新增 `_set_resource_ling_shi` 和 `_set_resource_ling_cai` 两个专用方法——GSM 接口表面积继续增长。但这是架构委托的既定模式（CombatSystem 定义 `_set_battle_*`，ExplorationSystem 定义 `set_exploration_*`）——一致的代价

### 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 调用方绕过 ResourceSystem 直接写 `GSM.player.resources` | 中 | 余额校验跳过、信号遗漏 | 代码审查检查清单纳入"资源写入必须通过 ResourceSystem"。GUT 测试注入直接写入场景——验证 batch_updated 不触发时 HUD 不一致的可见症状 |
| `const Dictionary` 公式表被意外修改 | 低 | 运行时公式错误 | 团队约定：公式表只读。GUT 冒烟测试验证基准值（`DISMANTLE_BASE[0] == 10` 等）。与 ADR-0010 `const realm_table` 风险一致 |
| `spend_resource` 的 `can_spend` 前置校验可被跳过 | 低 | 资源变负数 | `GSM._set_resource_ling_shi` 内部 `max(0, value)` 作为最后防线——即便绕过 ResourceSystem，GSM 层面的非负守卫防止负数 |
| 灵材品质裸 int 传入（绕过 LingCaiQuality 枚举） | 低 | 无效品质导致静默失败 | `add_resource` / `spend_resource` 入口处 `if quality < 1 or quality > 4: return false`——GDScript 无编译时枚举强制，运行时守卫是最佳实践 |

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| resource-system.md | §1 资源类型定义——灵石+灵材（4 级品质） | `LingCaiQuality` 枚举 + `add/spend/get` API 支持 quality 参数 |
| resource-system.md | §2 灵石经济模型——全收入/支出渠道 | 7 条公式 API 覆盖拆解、删卡、出售、境界惩罚、身份加成——所有下游系统通过统一接口查询 |
| resource-system.md | §3 灵材经济模型——品质分级 + 出售价 | `sell_ling_cai_value(quality, quantity)` 公式——商店系统调用 |
| resource-system.md | §4 资源存储位置——GSM `player.resources.*` | 确立 GSM 为唯一数据存储点，ResourceSystem 为唯一写入入口 |
| resource-system.md | §5 资源变更接口——add/spend/get | 定义类型安全 API；`can_spend()` 为消费前置校验 |
| resource-system.md | §1b 炼制物拆解折价 50% | `dismantle_crafted_value(rarity, level)` 独立公式 |
| resource-system.md | §3 删卡费用——50+25×(N-1) | `delete_card_cost(delete_count)` 公式 |
| resource-system.md | §7 境界差额灵石惩罚 | `realm_gap_penalty(player_L, map_max_L)` 公式——探索系统在通关奖励结算时调用 |
| resource-system.md | §6 身份天赋灵石加成 | `apply_ling_shi_bonus(base, multiplier)` 公式 |
| resource-system.md | §8 拆解卡牌→灵石 | `dismantle_value(rarity, level)` 公式——卡组编辑系统调用 |

## 性能影响
- **CPU**：所有公式为纯整数/浮点运算——单次调用 <0.001ms。`add_resource` / `spend_resource` 含一次字典查找 + 一次 GSM 第二层调用——总计 <0.01ms。非热路径（仅在事件/结算时调用，非每帧）
- **内存**：const 公式表（4 个数组 + 4 个常量）<200B。Autoload 节点 <1KB。总计常驻内存 <2KB
- **加载时间**：零——const 数据编译时分配，`_ready()` 为空
- **网络**：不适用（单机游戏）

## 迁移计划
本 ADR 为新建架构——无现有代码需迁移。实现顺序：
1. 创建 `res://src/core/resource_system.gd`——公式表 + 读写 API + LingCaiQuality 枚举
2. 在 `project.godot` 中注册 Autoload（排在 GSM 之后）
3. 在 GSM 中添加 `_set_resource_ling_shi` 和 `_set_resource_ling_cai` 第二层方法——纳入 ADR-0001 API
4. 下游系统实现时：从硬编码公式迁移到 `ResourceSystem.dismantle_value()` 等调用
5. GUT 测试覆盖公式正确性和余额校验

## 验证标准
- **GIVEN** player.resources.ling_shi=50，**WHEN** `spend_resource(&"ling_shi", 30)`，**THEN** 返回 true，ling_shi=20，`batch_updated` 信号已发射
- **GIVEN** player.resources.ling_shi=20，**WHEN** `spend_resource(&"ling_shi", 30)`，**THEN** 返回 false，ling_shi 仍为 20，无信号发射
- **GIVEN** rarity=3, level=1，**WHEN** `dismantle_value(3, 1)`，**THEN** 返回 100（紫卡基础值）
- **GIVEN** rarity=5, level=20，**WHEN** `dismantle_value(5, 20)`，**THEN** 返回 3900
- **GIVEN** rarity=4, level=1, is_crafted，**WHEN** `dismantle_crafted_value(4, 1)`，**THEN** 返回 200（金卡炼制物折价 50%）
- **GIVEN** delete_count=5，**WHEN** `delete_card_cost(5)`，**THEN** 返回 150（50+25×4）
- **GIVEN** player_L=3, map_max_L=1，**WHEN** `realm_gap_penalty(3, 1)`，**THEN** 返回 0.4
- **GIVEN** invalid quality=5，**WHEN** `add_resource(&"ling_cai", 1, 5)`，**THEN** 返回 false

## 相关决策
- ADR-0001（游戏状态管理器——`player.resources` 域数据所有权、GSM 第二层原子写入方法、`batch_updated` Cat 1 信号）
- ADR-0007（三分类信号体系——资源变更通过 Cat 1 GSM `batch_updated` 传播，不重复定义信号）
- ADR-0010（境界系统——`realm_gap_penalty` 公式引用境界数据）
- ADR-0012（跨局元进度——资源不跨局继承，天赋可提供开局额外灵石）
- ADR-0006（卡牌数据模型——`dismantle_value` 公式引用卡牌稀有度和等级）
- ADR-0008（战斗系统——战斗结算时通过 ResourceSystem 发放灵石奖励）
- ADR-0014（探索系统——地图通关奖励 + 境界差额惩罚通过 ResourceSystem 结算）