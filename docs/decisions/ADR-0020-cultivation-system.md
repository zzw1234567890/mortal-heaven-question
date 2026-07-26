# ADR-0020：修为养成系统 — Feature 层 Autoload + GSM 数据存储 + 统一获取接口

## 状态
Proposed

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Cultivation |
| **知识风险** | LOW（仅使用整数运算、GSM 第二层写入 API、信号系统——均为 Godot 4.x 成熟 API） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **使用的截止后 API** | None——核心逻辑（整数累加、溢出判定、信号发射）不依赖 4.4+ 新增 API |
| **需要验证** | `gain_cultivation()` 的同帧去重一致性——战斗结算+丹药使用在同帧发生时信号仅发射最终值；`overflow_pool` 的上限安全范围——理论上无上限，但需 GUT 测试验证截断逻辑；`CONVERSION_RATE` 和 `PILL_CONVERSION_UNIT` 的调优参数是否与数据库表一致 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`player.cultivation` 和 `player.overflow_pool` 数据存储所有权；GSM 第二层原子写入方法；`batch_updated` Cat 1 信号传播修为变更）；ADR-0007（三分类信号体系——`cultivation_changed`/`cultivation_full` 分类为 Cat 1 GSM 状态信号）；ADR-0010（RealmSystem——`get_current_property(&quot;max_cultivation&quot;)` 查询当前境界修为上限；`realm_upgraded` 信号触发突破后溢出结算） |
| **启用** | 渡劫突破系统（TribulationSystem——`check_breakthrough(cultivation, max_cultivation)` 判定是否可触发突破）；HUD 系统（修为进度条显示——订阅 `batch_updated` Cat 1 信号刷新）；战斗系统（CombatSystem——战斗胜利结算修为奖励）；探索系统（ExplorationSystem——探索事件中修为获取）；资源系统/炼丹系统（ResourceSystem——丹药使用修为获取） |
| **阻塞** | 渡劫突破 Epic（突破前置条件判定、突破后溢出结算、修为溢出属性丹发放）；战斗结算 Epic（战斗胜利修为奖励的发放流程）；探索 Epic（探索事件中的修为获取与溢出处理）；HUD Epic（修为进度条的实时刷新） |
| **排序说明** | Feature 层初中期 ADR。在 Foundation 层全部 7 个 ADR + Core 层关键依赖（ADR-0010 RealmSystem）被接受后编写。Autoload 初始化顺序 #20——排在 SchoolSystem（#19）之后。链：GSM #1 → … → AISystem #18 → SchoolSystem #19 → CultivationSystem #20。CultivationSystem 在 `_ready()` 时无显式初始化需求——所有逻辑为按需调用的纯函数+GSM 交互 |

## 上下文

### 问题陈述

`cultivation-system.md` GDD 定义了修为养成系统的完整规则——6 条修为获取途径（战斗胜利、丹药使用、地图事件、杀人夺宝、溢出转化、轮回天赋加成）、修为上限公式（`max_cultivation = BASE_MAX × 1.5^(realm_level - 1)`）、溢出池机制（满值后多余修为转入溢出池保留）、突破后溢出结算（`pill_count = floor(overflow_pool / PILL_CONVERSION_UNIT)` 发放属性丹）、以及修为满值提示逻辑。但 GDD 未解决以下架构问题：

1. **系统形态和层归属**：CultivationSystem 是独立 Autoload 还是嵌入 GSM？`architecture.md` 将其归入 Feature 层——与 CombatSystem、ExplorationSystem 等同级。但修为数据的存储和访问模式与 ResourceSystem（ADR-0019）高度相似——数据在 GSM，逻辑在独立服务层
2. **修为数据存储位置**：`cultivation` 值和 `overflow_pool` 值需要跨战斗持久化（存档/读档恢复）——存储在 GSM `player.*` 域中符合 ADR-0001 的"所有玩家状态在 GSM"原则。但在战斗热路径中，战斗结算时需要写入修为——是通过 GSM 第二层还是 CultivationSystem 内部缓存？
3. **修为获取接口统一性**：6 条获取途径（战斗、丹药、事件、夺宝、溢出转化、天赋加成）都调用同一个 `gain_cultivation(amount, source)` 入口——这个入口由谁提供？如何保证所有调用方都经过同一个溢出判定逻辑？
4. **信号策略**：GDD 明确标注 `GSM.emit_signal("cultivation_changed")` 和 `GSM.emit_signal("cultivation_full")`——这些信号应该归属 Cat 1（GSM 状态信号）还是 Cat 2b（系统特定信号）？ADR-0007 的三分类体系如何适用？
5. **溢出池的管理边界**：溢出转化在 `gain_cultivation()` 内部自动处理——但突破后属性丹结算由谁触发？RealmSystem 的 `realm_upgraded` 信号（Cat 2b）还是 CultivationSystem 的内部判断？

### 约束

- **GSM 数据所有权不变**：`player.cultivation: float` 和 `player.overflow_pool: int` 的所有权在 GSM——CultivationSystem 不持有数据副本（与 ADR-0019 ResourceSystem 模式完全一致）
- **Feature 层定位**：CultivationSystem 是 Feature 层 Autoload——依赖 Foundation 层（GSM）和 Core 层（RealmSystem），被 Feature 层（CombatSystem、ExplorationSystem、TribulationSystem）和 Presentation 层（HUD）消费
- **max_cultivation 来源**：修为上限随境界动态变化——由 RealmSystem 提供（ADR-0010 已定义 `realm_table[L]["max_cultivation"]`），CultivationSystem 不自行维护上限表
- **溢出保留策略**：修为满值后获得的修为全部转入溢出池——不丢失。突破失败时修为损失 10% 由渡劫系统处理，不影响溢出池
- **信号归属**：`cultivation_changed` 和 `cultivation_full` 语义上属于"GSM 数据已变更"通知——消费者为 HUD/渡劫系统，数量不确定——符合 Cat 1 判定条件
- **帧预算**：战斗结算时 `gain_cultivation()` 调用一次（O(1) 整数计算+一次 GSM 写入）< 0.1ms；`get_progress()` 查询 < 0.001ms

### 需求

- 统一的修为获取入口：`gain_cultivation(amount: int, source: CultivationSource) → void`——所有 6 条途径的唯一调用点
- 溢出池自动管理：获取时自动判定溢出→转入溢出池；突破后自动结算→属性丹发放
- 修为满值检测：`cultivation >= max_cultivation` 时自动发射 `cultivation_full` 信号
- 只读查询接口：`get_cultivation() → int`、`get_max_cultivation() → int`、`get_overflow_pool() → int`、`get_progress() → float`
- GSM 信号传播：修为变更通过 GSM `batch_updated`（Cat 1）传播——HUD 和渡劫系统订阅 GSM 信号刷新
- 突破后结算委托：`realm_upgraded`（Cat 2b）信号触发溢出池→属性丹结算

## 决策

**CultivationSystem 作为 Feature 层独立 Autoload（`res://src/feature/cultivation/cultivation_system.gd`）实现——采取"数据存储委托 GSM + 纯逻辑服务层"的架构模式（与 ADR-0019 ResourceSystem 模式一致）。所有修为数据存储在 GSM `player.*` 域中，CultivationSystem 提供 `gain_cultivation()` 统一入口（内含溢出判定和信号触发的完整逻辑链），各修为来源系统通过直接调用 `gain_cultivation()` 发放修为，HUD 和渡劫系统通过订阅 GSM Cat 1 信号（`batch_updated`）响应修为变更。**

### 层分类决议：Feature 层论证

`architecture.md` 将"修为养成系统"归入 Feature 层——是垂直游戏功能而非基础设施。这与 CombatSystem、ExplorationSystem、TribulationSystem 同级定位一致。虽然其架构模式（数据委托 GSM + 纯逻辑服务层）与 Core 层的 ResourceSystem 相似，但修为养成是游戏玩法内容（影响玩家成长循环）而非横切基础设施——Feature 层是正确的语义归属。

### 对象模型与架构图

```
┌──────────────────────────────────────────────────────────────┐
│                    GSM (ADR-0001)                             │
│  player.cultivation: int    ← 运行时修为值                     │
│  player.overflow_pool: int  ← 累计溢出修为                     │
│  _set_cultivation(value) → void  (原子写入 + batch_updated)    │
│  _set_overflow_pool(value) → void                              │
│  batch_updated(changes) → Cat 1 信号                          │
│    ├─ "player.cultivation": {old, new}                        │
│    └─ "player.overflow_pool": {old, new}                      │
└──────────────┬───────────────────────────────────────────────┘
               │ 数据存储所有权
               ▼
┌──────────────────────────────────────────────────────────────┐
│         CultivationSystem (ADR-0020) — Feature Autoload       │
│                                                               │
│  ┌─ 调优参数（const 编译时常量）──────────────────┐          │
│  │ CONVERSION_RATE: float = 1.0      # 100%        │          │
│  │ PILL_CONVERSION_UNIT: int = 100   # 100溢出=1丹  │          │
│  └─────────────────────────────────────────────────┘          │
│                                                               │
│  ┌─ 写入 API ─────────────────────────────────────┐          │
│  │ gain_cultivation(amount, source) → void         │          │
│  │   ├─ amount <= 0 → return (无变化)               │          │
│  │   ├─ 计算 available = max - current              │          │
│  │   ├─ 直接累加：current += min(amount, available)  │          │
│  │   ├─ 溢出转化：overflow_pool += excess × RATE    │          │
│  │   ├─ 原子写入 GSM（cultivation + overflow_pool）  │          │
│  │   │   → GSM._set_cultivation(new_value)           │          │
│  │   │   → GSM._set_overflow_pool(new_value)         │          │
│  │   │   → GSM 内部触发 batch_updated(合并变更)      │          │
│  │   ├─ 检查满值：if current >= max → 发射特殊通知   │          │
│  │   │   → GSM.batch_updated 载荷中附带               │          │
│  │   │     "player.cultivation_full": true 标记       │          │
│  │   └─ 日志记录：source + amount + 溢出量            │          │
│  │                                                   │          │
│  │ settle_overflow() → int                           │          │
│  │   ├─ pill_count = floor(pool / PILL_UNIT)         │          │
│  │   ├─ overflow_pool -= pill_count × PILL_UNIT      │          │
│  │   ├─ 发放 pill_count 个属性丹到背包                │          │
│  │   └─ 返回 pill_count                              │          │
│  └───────────────────────────────────────────────────┘          │
│                                                               │
│  ┌─ 查询 API ─────────────────────────────────────┐          │
│  │ get_cultivation() → int       # GSM 直接读取     │          │
│  │ get_max_cultivation() → int   # RealmSystem 查询  │          │
│  │ get_overflow_pool() → int     # GSM 直接读取     │          │
│  │ get_progress() → float        # 0.0~1.0 归一化   │          │
│  │ check_breakthrough() → bool   # cultivation>=max │          │
│  └───────────────────────────────────────────────────┘          │
│                                                               │
│  ┌─ 信号订阅（突破后结算委托）────────────────────┐          │
│  │ RealmSystem.realm_upgraded.connect(_on_realm_up)│          │
│  │   → settle_overflow()  # 突破成功后立即结算      │          │
│  └───────────────────────────────────────────────────┘          │
└──────────────┬───────────────────────────────────────────────┘
               │ gain_cultivation() 统一入口
               ▼
   ┌───────────┬──────────┬──────────┬──────────┬──────────┐
   │ Combat    │ Explore  │ Resource │ Event    │Talent    │
   │ System    │ System   │ System   │ System   │ System   │
   │(战斗奖励) │(事件修为)│(丹药修为)│(夺宝修为)│(天赋加成)│
   │           │          │          │          │          │
   │ gain_cult │ gain_cult│ gain_cult│ gain_cult│ gain_cult│
   │(amount,   │(amount,  │(amount,  │(amount,  │(amount,  │
   │ BATTLE)   │EXPLORE)  │PILL)     │EVENT)    │TALENT)   │
   └───────────┴──────────┴──────────┴──────────┴──────────┘

   ┌───────────┐          ┌───────────┐
   │   HUD     │          │Tribulation│
   │(修为进度) │          │ System    │
   │           │          │(突破判定) │
   │ GSM.batch │          │check_brk()│
   │ _updated  │          │           │
   │.connect() │          │           │
   └───────────┘          └───────────┘
```

### 信号策略详解

```
修为变更的完整信号传播链（遵循 ADR-0007 三分类体系）：

1. CultivationSystem.gain_cultivation(amount, source)  # 直接调用入口
2.   → GSM._set_cultivation(new_value)                  # GSM 第二层原子写入
3.     → GSM.batch_updated.emit({                       # Cat 1 信号（ADR-0007）
4.         "player.cultivation": {old, new},              #   数据已变更，消费者未知
5.         "player.overflow_pool": {old, new},            #   广播给所有订阅者
6.         "player.cultivation_full": true|false          #   满值状态标记位
7.       })
8.         → HUD._on_batch_updated(changes)              # UI 刷新修为进度条
9.         → TribulationSystem._on_cultivation_changed()  # 突破前置条件检查

10. RealmSystem.realm_upgraded.connect(_on_realm_up)     # Cat 2b 信号订阅（ADR-0007）
11.   → CultivationSystem.settle_overflow()              # 突破成功后溢出池→属性丹
12.     → ResourceSystem.add_resource("attribute_pill")  # 属性丹发放
13.     → GSM._set_overflow_pool(remaining)              # 更新剩余溢出值
```

**信号归属论证**：
- `cultivation_changed` → **Cat 1（GSM 状态信号）**，不创建独立信号。消费者为 HUD + TribulationSystem + 未来可能的成就系统——数量不确定，符合 Cat 1 判定条件。通过 `batch_updated` 的载荷键名 `player.cultivation` 区分——消费者按路径过滤
- `cultivation_full` → **Cat 1 状态标记位**，非独立信号。在 `batch_updated` 载荷中附带布尔标记——消费者无需额外订阅即可获取满值状态。避免创建独立信号导致 HUD 同时订阅两个 Cat 1 信号的冗余
- `realm_upgraded` → **Cat 2b（系统特定信号）**，由 RealmSystem 发射。CultivationSystem 作为消费者订阅——突破成功后立即结算溢出池。这是跨系统委托的标准模式（与 ADR-0010 的 design 一致）

### GDD 信号声明与 ADR-0007 分类的对齐

GDD `cultivation-system.md` 的伪代码使用 `GSM.emit_signal("cultivation_changed")` 和 `GSM.emit_signal("cultivation_full")`——本 ADR 将其映射为 **GSM `batch_updated` Cat 1 信号的载荷键名**（`player.cultivation` + `player.cultivation_full` 标记位），而非在 GSM 上新增独立信号。这避免了 GSM 信号接口膨胀（已有 5 个 Cat 1 信号——见 ADR-0007 汇总表），符合 ADR-0007 禁止模式 #1（GSM 不成为信号总线）。GDD 中的伪代码是产品语言的简化表达，本 ADR 落实为架构层面的具体信号路由。

### 关键接口

```gdscript
# === CultivationSystem Autoload ===

## 调优参数 —— 策划在此调整修为养成数值
const CONVERSION_RATE: float = 1.0       # 溢出转化率（100% = 无损耗）
const PILL_CONVERSION_UNIT: int = 100    # 每枚属性丹所需溢出修为

## 修为获取来源枚举
enum CultivationSource {
    BATTLE,     # 战斗胜利
    PILL,       # 丹药使用
    EXPLORE,    # 探索事件
    EVENT,      # 杀人夺宝事件
    OVERFLOW,   # 溢出转化（内部自动触发）
    TALENT,     # 轮回天赋加成
}

## 统一获取入口 —— 所有修为来源系统的唯一调用点
## amount <= 0 时静默返回（不发射信号，不修改 GSM）
## source 参数用于日志追踪和成就系统统计
func gain_cultivation(amount: int, source: CultivationSource) -> void:
    if amount <= 0: return
    var max_cult: int = RealmSystem.get_current_property(&"max_cultivation")
    var current: int = GSM.player.cultivation
    var available: int = max_cult - current

    var actual_gain: int = mini(amount, available)
    var overflow_raw: int = maxi(0, amount - available)
    var overflow_converted: int = int(ceil(overflow_raw * CONVERSION_RATE))

    # 原子写入 GSM（合并一次 batch_updated）
    GSM._set_cultivation(current + actual_gain)
    if overflow_converted > 0:
        GSM._set_overflow_pool(GSM.player.overflow_pool + overflow_converted)

    # 日志追踪
    _log_cultivation_event(source, amount, actual_gain, overflow_raw, overflow_converted)

## 突破后溢出结算 —— 由 RealmSystem.realm_upgraded 信号触发
## 返回本次结算获得的属性丹数量
func settle_overflow() -> int:
    var pool: int = GSM.player.overflow_pool
    var pill_count: int = floori(pool / PILL_CONVERSION_UNIT)
    if pill_count <= 0: return 0

    GSM._set_overflow_pool(pool - pill_count * PILL_CONVERSION_UNIT)
    # 委托 ResourceSystem 发放属性丹到玩家背包
    ResourceSystem.add_resource("attribute_pill", pill_count)
    return pill_count

## 只读查询 —— 零开销直接读取
func get_cultivation() -> int:       return GSM.player.cultivation
func get_overflow_pool() -> int:     return GSM.player.overflow_pool
func get_max_cultivation() -> int:   return RealmSystem.get_current_property(&"max_cultivation")
func get_progress() -> float:        return float(GSM.player.cultivation) / float(get_max_cultivation())
func check_breakthrough() -> bool:   return GSM.player.cultivation >= get_max_cultivation()

## _ready() 中连接 — RealmSystem 突破信号触发溢出结算
func _ready() -> void:
    RealmSystem.realm_upgraded.connect(_on_realm_upgraded)

func _on_realm_upgraded(old_level: int, new_level: int) -> void:
    settle_overflow()
```

### GSM 新增接口（窄范围写委托）

```gdscript
# === GSM 新增方法（ADR-0001 第二层原子写入扩展） ===

## 修为值原子写入 —— 仅 CultivationSystem 调用
## 触发 batch_updated Cat 1 信号，载荷含 cultivation_full 标记位
func _set_cultivation(value: int) -> void:
    var old: int = player.cultivation
    player.cultivation = value
    var max_val: int = RealmSystem.get_current_property(&"max_cultivation")
    _emit_batch_updated({
        "player.cultivation": {"old": old, "new": value},
        "player.cultivation_full": value >= max_val,
    })

## 溢出池原子写入 —— 仅 CultivationSystem 调用
func _set_overflow_pool(value: int) -> void:
    var old: int = player.overflow_pool
    player.overflow_pool = value
    # 溢出池变更附加到同帧 batch_updated 中（如果与 _set_cultivation 同帧则合并）
    _queue_batch_update("player.overflow_pool", {"old": old, "new": value})
```

### 接口契约

| 接口 | 签名 | 调用方 | 被调用方 | 分类 (ADR-0007) |
|------|------|--------|---------|-----------------|
| 修为获取 | `CultivationSystem.gain_cultivation(amount, source) → void` | CombatSystem、ExplorationSystem、ResourceSystem、EventSystem、TalentSystem | CultivationSystem → GSM | 直接调用（编排器→子系统） |
| 溢出结算 | `CultivationSystem.settle_overflow() → int` | CultivationSystem（内部，由信号触发） | CultivationSystem → ResourceSystem | Cat 2b 信号订阅驱动 |
| 状态查询 | `CultivationSystem.get_cultivation() → int` | HUD、TribulationSystem | CultivationSystem → GSM（只读） | 直接调用（零开销查询） |
| 进度查询 | `CultivationSystem.get_progress() → float` | HUD | CultivationSystem → GSM + RealmSystem | 直接调用 |
| 突破判定 | `CultivationSystem.check_breakthrough() → bool` | TribulationSystem | CultivationSystem → GSM + RealmSystem | 直接调用 |
| 状态写入 | `GSM._set_cultivation(value) → void` | CultivationSystem | GSM | 直接调用（GSM 第二层原子写入） |
| 状态写入 | `GSM._set_overflow_pool(value) → void` | CultivationSystem | GSM | 直接调用（GSM 第二层原子写入） |
| 突破信号 | `RealmSystem.realm_upgraded(old, new)` | RealmSystem | CultivationSystem | Cat 2b（ADR-0007——系统特定事件通知） |

## 考虑的替代方案

### 替代方案 A（选定）：独立 CultivationSystem Autoload + GSM 数据存储委托

- **描述**：CultivationSystem 为 Feature 层 Autoload，持有 `gain_cultivation()` 统一获取逻辑和溢出判定算法，但所有数据存储在 GSM `player.*` 域中。修为变更通过 GSM Cat 1 `batch_updated` 信号传播，HUD/TribulationSystem 订阅 GSM 信号刷新。突破后溢出结算通过订阅 RealmSystem 的 Cat 2b `realm_upgraded` 信号触发。
- **优点**：
  - 与 ADR-0019 ResourceSystem 模式完全一致——团队已有此架构模式的认知基础，学习成本低
  - 统一入口`gain_cultivation()`强制所有修为来源经过相同的溢出判定逻辑——杜绝来源系统各自实现溢出公式的 bug 风险
  - GSM 数据所有权不变——`player.cultivation` 和 `player.overflow_pool` 随存档自动序列化/反序列化，无需额外序列化逻辑
  - 信号归属明确——修为变更走 Cat 1（GSM 状态广播），突破事件走 Cat 2b（系统间委托）——完全符合 ADR-0007 三分类体系
  - Autoload 数量 25 个（本批次 7 个 ADR 并行创建：ADR-0020 修炼/0021 渡劫/0022 身份/0023 卡组/0024 阵法/0025 流派/0026 剧情）。本批次是 Autoload 数量的重大里程碑（18→25）。CultivationSystem 注册为 #20
- **缺点**：
  - 增加 1 个 Autoload——项目 Autoload 总数从 18 增至 25（本批次 7 个 ADR 并行创建）
  - GSM 需新增 2 个窄范围写委托方法（`_set_cultivation`、`_set_overflow_pool`）——GSM 接口表面积微增
  - 调用方需同时引用 CultivationSystem（获取入口）和 GSM（读取值）——但这与 ResourceSystem 的调用模式一致，团队已习惯

### 替代方案 B：嵌入 GSM 内部——修为逻辑作为 GSM 第二层方法

- **描述**：不创建独立 Autoload——`gain_cultivation()`、`settle_overflow()`、`check_breakthrough()` 作为 GSM 的第二层原子操作方法。`max_cultivation` 在 GSM 内部通过 RealmSystem 查询。所有修为逻辑封装在 GSM 内部，调用方直接调用 `GSM.gain_cultivation(amount, source)`。
- **优点**：
  - 零 Autoload 增量——项目保持在 18 个（本批次扩张至 25）
  - 调用方仅需引用 GSM——减少跨系统引用
  - 修为逻辑与数据存储在同一对象内——概念简单
- **缺点**：
  - GSM 成为"上帝对象"——在已有 35 个消费者 + 10+ 原子方法基础上再增加 3 个领域特定方法。违反单一职责原则（GSM 的职责是运行时状态管理，不是修为养成业务逻辑）
  - 无法统一定义 `CultivationSource` 枚举——嵌入 GSM 会导致 GSM 需了解所有修为来源系统（战斗/丹药/探索/事件/天赋）的业务语义
  - `CONVERSION_RATE` 和 `PILL_CONVERSION_UNIT` 等调优参数嵌入 GSM——策划调整修为数值时需修改 Foundation 层最敏感文件，修改风险高
  - GSM `batch_updated` 载荷将附带 `player.cultivation_full` 标记位——无论采用方案 A 还是 B，这是固定开销，不因方案选择而改变
  - GDD 的伪代码标注 `GSM.emit_signal("cultivation_changed")` 是产品语言的简化表达，非架构约束——架构层面应采用 Cat 1 `batch_updated` 模式（ADR-0007 禁止模式 #1：GSM 不成为信号总线）
- **拒绝原因**：GSM 的规模已达到 35 个消费者 + 10+ 域 + 10+ 原子方法——继续添加领域特定逻辑将进一步违反单一职责原则。修为养成是完整的游戏玩法循环（获取→溢出→满值→突破→结算），其逻辑复杂度和调优参数量值得拥有独立的架构单元。FSM（Finite State Machine）和 AI 等系统也有类似复杂度的逻辑——但它们各自拥有独立 Autoload 而没有嵌入 GSM——培养系统不应例外。

### 替代方案 C：修为数据内部管理——如 CostSystem（ADR-0015）的内部状态模式

- **描述**：CultivationSystem 内部维护 `_cultivation` 和 `_overflow_pool` 变量——如同 CostSystem 管理 `_current_cost` / `_max_cost` / `_temp_bonus`。战斗热路径中的修为写入在内部变量上进行，战斗结束时通过 `serialize_to_gsm()` 导出快照至 GSM。
- **优点**：
  - 战斗热路径中修为变更不经过 GSM——减少 GSM 的写入压力（虽然单次写入 <0.1ms）
  - 内部状态管理提供更好的封装性——GSM 仅接收最终值，不接触中间计算
- **缺点**：
  - 违反 GDD 的实时修为显示需求——HUD 需要实时显示修为进度（始终可见的修为条 + 飘字动画）。内部缓存模式导致 HUD 无法通过 GSM `batch_updated` 信号获取实时值
  - 序列化复杂度增加——需要 `serialize_to_gsm()` / `deserialize_from_gsm()` 双向转换，增加存档/读档路径复杂度
  - 与同一架构层的 ResourceSystem（ADR-0019）模式不一致——同样是"数据在 GSM + 逻辑在独立服务"，ResourceSystem 选择了数据委托模式而非内部缓存模式。不一致的模式增加团队认知负担
  - `overflow_pool` 跨战斗持久——战斗间的溢出池值必须保留（突破前可能积累多次战斗的溢出）。内部缓存模式要求在每场战斗开始时从 GSM 恢复溢出池值，增加了初始化复杂度
- **拒绝原因**：修为数据需要实时显示（HUD 修为条）和跨战斗持久（溢出池保留）——这两个需求天然倾向数据存储在 GSM（提供实时信号广播 + 存档序列化）。内部缓存模式是战斗热路径专用模式（ADR-0011 StatusEffectSystem、ADR-0013 BindingManager、ADR-0016 DeploymentSystem），适用于仅在战斗上下文中有意义、战斗结束后归档至 GSM 的数据。修为数据是横跨战斗/探索/突破的全局玩家状态——不符合"内部缓存"模式的应用前提。

## 后果

### 积极的

- **架构模式一致性**：与 ResourceSystem（ADR-0019）的"数据委托 GSM + 纯逻辑服务层"模式完全一致——团队已有此模式的认知基础，降低实现和维护成本
- **统一获取入口**：`gain_cultivation(amount, source)` 是所有修为来源的唯一调用点——计算溢出、触发信号、记录日志的逻辑集中在一处。杜绝了 CombatSystem 和 ExplorationSystem 各自实现溢出公式的 W-C4 类 bug（与跨 ADR 审计中发现的重复定义模式相同）
- **信号体系合规**：修为变更走 GSM Cat 1 `batch_updated`（数据变更广播）+ 突破委托走 Cat 2b `realm_upgraded`（系统间事件通知）——严格遵循 ADR-0007 三分类体系。不创建冗余信号，不在 GSM 上添加独立信号
- **GSM 数据所有权不变**：`player.cultivation` 和 `player.overflow_pool` 随 GSM `serialize()` / `deserialize()` 自动持久化——存档系统无需额外的修为序列化逻辑
- **策划友好**：`CONVERSION_RATE` 和 `PILL_CONVERSION_UNIT` 在 CultivationSystem 顶层以 `const` 常量定义——调优时修改单个文件即可，无需触及 GSM（Foundation 层最敏感文件）
- **突破后结算解耦**：CultivationSystem 通过订阅 RealmSystem 的 Cat 2b 信号触发溢出结算——不直接依赖 TribulationSystem。TribulationSystem 也不直接调用 CultivationSystem——两个系统通过 RealmSystem 信号完全解耦

### 消极的

- **Autoload 数量增至 25**：从 18 个增至 25 个（本批次 7 个 ADR 并行创建：ADR-0020 修炼/0021 渡劫/0022 身份/0023 卡组/0024 阵法/0025 流派/0026 剧情）。本批次是 Autoload 数量的重大里程碑——CultivationSystem 注册为 #20，排在 SchoolSystem（#19）之后。后续 ADR 需持续跟踪 Autoload 扩容趋势
- **GSM 接口微增**：需新增 `_set_cultivation()` 和 `_set_overflow_pool()` 两个窄范围写委托方法——虽然新增量小（2 个方法），但 GSM 接口表面积持续膨胀的趋势值得关注
- **调用方双引用**：修为来源系统（CombatSystem、ExplorationSystem、ResourceSystem）在发放修为时需同时引用 CultivationSystem（调用 `gain_cultivation`）和 GSM（先读取当前修为值用于 UI 判断）——这与 ResourceSystem 的调用模式一致，但仍增加了一个系统引用

### 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| `batch_updated` 载荷中的 `cultivation_full` 标记位被消费者忽略 | 低 | HUD 不显示"修为已满"提示，玩家错过突破时机 | 在 HUD ADR 中明确订阅规范——HUD `_on_batch_updated()` 处理器必须检查 `player.cultivation_full` 标记位。GUT 集成测试覆盖满值检测→提示触发 |
| 同帧多次 `gain_cultivation()` 导致 `batch_updated` 重复发射 | 低 | UI 重复刷新，每帧超预算 | GSM 同帧去重规则（ADR-0001）已内置——同一路径多次写入仅发射一次信号。`_set_cultivation` 和 `_set_overflow_pool` 同帧调用的变更被合并为一个 `batch_updated` 载荷 |
| `CONVERSION_RATE` 修改后溢出收益过大或过小 | 中 | 溢出机制失效——玩家不关心溢出或溢出过于强力 | 调优参数有安全范围（50%-100%）——通过 GUT 参数化测试验证公式输出。TRIBE 协议（Tuning/Rig/Iterate/Balance/Economy）确保上线前调优验证 |
| `overflow_pool` 无限增长导致大数字问题 | 低 | 单局理论上限 <10000（受满值后获取次数限制），溢出池超过 int 范围 | 调优参数文档明确标注安全上限。`settle_overflow()` 使用 `floori()` 整数除法确保溢出池截断。GUT 边界测试验证超大溢出值 > 10000 |
| `settle_overflow()` 中属性丹发放失败 | 低 | 玩家突破后未获得应得的属性丹 | `ResourceSystem.add_resource()` 返回 bool——失败时记录错误日志 + push_warning。属性丹发放是确定性事件（非随机），重试逻辑由 ResourceSystem 内部保证 |

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| cultivation-system.md | §1「修为获取途径」——6 条途径的统一接口 | `gain_cultivation(amount, source)` 统一入口 + `CultivationSource` 枚举定义 6 条途径的完整语义 |
| cultivation-system.md | §2「修为上限公式」——`max_cultivation = BASE_MAX × 1.5^(realm_level - 1)` | `get_max_cultivation()` 通过 `RealmSystem.get_current_property(&"max_cultivation")` 查询——上限公式和数值表由 ADR-0010 RealmSystem 集中定义 |
| cultivation-system.md | §3「修为溢出转化」——满值后多余修为转入溢出池保留 | `gain_cultivation()` 内部自动计算 `available` 容量 + `overflow_raw` 超额 + `overflow_converted` 转化——一条调用完成全部逻辑 |
| cultivation-system.md | §4「修为满值提示」——`cultivation >= max_cultivation` 时提示"可突破" | GSM `batch_updated` 载荷附带 `player.cultivation_full` 布尔标记位——HUD 订阅 Cat 1 信号即可获取满值状态 |
| cultivation-system.md | §5「修为获取流程」——含溢出判定的完整获取逻辑 | `gain_cultivation()` 伪代码完全映射为 GDScript 实现——amount ≤ 0 跳过、available 计算、溢出转化、信号触发 |
| cultivation-system.md | §6「突破后修为处理」——突破后保留当前修为值、更新上限、触发溢出结算 | `settle_overflow()` 订阅 `RealmSystem.realm_upgraded` Cat 2b 信号——突破成功后自动执行 `pill_count = floor(pool / 100)` 结算 |
| cultivation-system.md | §7「溢出属性丹自动发放」——`pool → pill_count × 属性丹 → GSM` | `ResourceSystem.add_resource("attribute_pill", pill_count)` 委托发放——属性丹类型由玩家手动选择（非本系统处理） |
| cultivation-system.md | §「调优参数」——CONVERSION_RATE、PILL_CONVERSION_UNIT、BASE_MAX 等 | 在本 ADR 中以 `const` 常量集中定义——策划在单一文件中调优，不触及 GSM |

## 性能影响

- **CPU**：`gain_cultivation()` 单次调用 <0.1ms（整数比较 + 1 次 RealmSystem 字典查询 + 1-2 次 GSM 原子写入 + 信号发射）。战斗结算时调用 1 次，每局约 5-10 次调用——总开销 <1ms/局。`get_progress()` 查询 <0.001ms（整数除法）——HUD 每帧调用零压力
- **内存**：CultivationSystem Autoload 节点 ≈ 0.5KB。`const` 常量 2 项 ≈ 16B。`CultivationSource` 枚举 ≈ 24B。总计 <1KB 常驻内存
- **加载时间**：`_ready()` 中仅连接 1 个信号（`RealmSystem.realm_upgraded`）——无异步加载，无文件 I/O，不增加启动时间
- **网络**：不适用（纯单机游戏）

## 迁移计划

本 ADR 创建新系统，非修改现有代码。实施顺序：

1. 在 GSM（ADR-0001）中新增两个窄范围写委托方法：`_set_cultivation(value: int)` 和 `_set_overflow_pool(value: int)`——内部包含 `batch_updated` 信号触发和 `cultivation_full` 标记位计算
2. 创建 `res://src/feature/cultivation/cultivation_system.gd` —— CultivationSystem Autoload（const 调优参数 + gain_cultivation/settle_overflow/查询 API）
3. 在 `project.godot` 中注册 Autoload #20——排在 SchoolSystem（#19）之后
4. CultivationSystem 的 `_ready()` 中连接 `RealmSystem.realm_upgraded` 信号——突破后溢出结算的委托触发点
5. 战斗系统实现战斗结算流程时：调用 `CultivationSystem.gain_cultivation(reward_amount, CultivationSource.BATTLE)` 替换原有的直接 GSM 写入
6. 探索系统实现探索事件修为奖励时：调用 `CultivationSystem.gain_cultivation(event_amount, CultivationSource.EXPLORE)`
7. ResourceSystem 实现丹药使用逻辑时：调用 `CultivationSystem.gain_cultivation(pill_amount, CultivationSource.PILL)`
8. HUD 实现修为进度条时：订阅 `GSM.batch_updated` 信号，过滤 `player.cultivation` 路径键 + 检查 `player.cultivation_full` 标记位

## Autoload 初始化链（更新至 25 个）

```
GSM #1 → InputManager #2 → SceneManager #3 → SaveLoadSystem #4 → EventSystem #5
→ CardSystem #6 → CostSystem #7 → StatusEffectSystem #8 → CombatSystem #9
→ CardEffectEngine #10 → RealmSystem #11 → ProgressionSystem #12
→ BindingManager #13 → ExplorationSystem #14 → FactionSystem #15
→ ResourceSystem #16 → DeploymentSystem #17 → AISystem #18
→ SchoolSystem #19 → CultivationSystem #20
→ IdentitySelectionSystem #21 → DeckEditingSystem #22
→ FormationSystem #23 → TribulationSystem #24 → StorySystem #25
```

CultivationSystem 的 `_ready()` 执行时，GSM（#1）和 RealmSystem（#11）已完全初始化——`gain_cultivation()` 内部的两项依赖（GSM 读写 + RealmSystem 属性查询）均已就绪。

## 验证标准

- **GIVEN** 炼气期修为 800/1000，**WHEN** 调用 `gain_cultivation(200, BATTLE)`，**THEN** 修为变为 1000/1000，溢出 100 转入溢出池
- **GIVEN** 炼气期修为 500/1000，**WHEN** 调用 `gain_cultivation(30, EXPLORE)`，**THEN** 修为变为 530/1000，溢出池不变
- **GIVEN** 修为已满且溢出池=450，**WHEN** `realm_upgraded` 信号触发 `settle_overflow()`，**THEN** 获得 4 属性丹，溢出池剩余 50
- **GIVEN** 修为已满，**WHEN** 调用 `gain_cultivation(100, PILL)`，**THEN** 全部走溢出转化，`cultivation_full` 标记位=true
- **GIVEN** 筑基期修为 800/1500，**WHEN** 突破至金丹（`RealmSystem.realm_upgraded` 信号），**THEN** `get_cultivation()` 返回 800，`get_max_cultivation()` 返回 2250
- **GIVEN** 调用 `gain_cultivation(0, BATTLE)`，**WHEN** 执行完毕，**THEN** GSM 不变，`batch_updated` 不发射（amount ≤ 0 静默返回）
- **GIVEN** 同帧调用 `gain_cultivation(100, BATTLE)` 和 `gain_cultivation(50, PILL)`，**WHEN** GSM 同帧去重完成后，**THEN** 仅发射一次 `batch_updated` 含最终值
- **GIVEN** HUD 订阅 `GSM.batch_updated`，**WHEN** 收到含 `player.cultivation_full: true` 载荷，**THEN** 修为条显示"已满"闪烁状态+提示文字
- 通过 GUT：`CultivationSystem` 测试套件覆盖——所有 `gain_cultivation` 分支（无溢出/部分溢出/全部溢出/零值/负值）、`settle_overflow` 结算公式、`check_breakthrough` 边界、`batch_updated` 载荷键名正确性

## 相关决策

- ADR-0001：游戏状态管理器 Autoload 三层 API —— `player.cultivation` 和 `player.overflow_pool` 数据存储所有权；GSM 第二层原子写入；`batch_updated` Cat 1 信号
- ADR-0007：三分类信号体系 —— `batch_updated` 载荷中的 `player.cultivation_full` 标记位分类为 Cat 1 状态信号；`realm_upgraded` 分类为 Cat 2b 系统特定事件信号
- ADR-0010：境界系统专用 Autoload —— `get_current_property(&"max_cultivation")` 查询修为上限；`realm_upgraded` 信号触发突破后溢出结算
- ADR-0019：资源系统 Core 层 Autoload —— 数据委托 GSM + 纯逻辑服务层的架构模式先例；`add_resource("attribute_pill")` 属性丹发放
- ADR-0015：费用系统 Core 层 Autoload —— 内部状态管理模式（替代方案 C 的参照）；非本 ADR 选定的模式
- architecture.md §「仍需创建的 ADR」—— 修炼养成系统列为 MVP 下一批优先级；本 ADR 将其正式完成