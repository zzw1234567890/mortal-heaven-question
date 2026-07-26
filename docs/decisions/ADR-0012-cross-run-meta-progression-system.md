# ADR-0012：跨局元进度系统 — ProgressionSystem Autoload + 领域化 API + 直写缓存模型

## 状态
Accepted（2026-07-26——Meta 层审查通过。修复：SaveLoad ADR-0003→0002、EventSystem ADR-0004→0003、层归属 Foundation→Meta、Autoload 计数更新。）

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Core / Meta-Progression |
| **知识风险** | LOW（仅使用 Dictionary、Signal、Autoload——全部自 4.0 起稳定） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/breaking-changes.md` |
| **使用的截止后 API** | None（所有 API——Dictionary、signal connect、Autoload——自 4.0 起稳定） |
| **需要验证** | 12 个 Autoload 的初始化顺序正确性（Godot 顺序 `_ready()` 保证——已验证，见初始化策略）；`progression_updated` → SaveLoadSystem 同步直写延迟每帧 <50ms；首局（无 progression.dat）默认值正确性；批量更新 API（batch_update_begin/end）在高频统计增量时的去重效果 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——但**取代** `progression.*` 域所有权）；ADR-0002（SaveLoadSystem——progression.dat 的持久化读写、`progression_saved` 信号——**同时也取代** SaveLoadSystem 的 `progression_updated` 信号源：从 `GSM.progression_updated` 改为 `ProgressionSystem.progression_updated`）；ADR-0007（信号分类体系——Cat 2b 动作通知信号） |
| **启用** | 成就系统（AchievementSystem）、轮回天赋系统（ReincarnationTalentSystem）、结局分支系统（EndingBranchSystem）——上述所有系统通过 ProgressionSystem API 读写跨局数据 |
| **阻塞** | **成就 Epic**（62 个成就的解锁/进度追踪）、**轮回天赋 Epic**（20 个天赋节点 + 槽位装备）、**结局图鉴 Epic**（6 个结局的解锁/展示）——在上述系统端到端测试前必须接受本 ADR |
| **排序说明** | Meta 层 ADR。Autoload 初始化顺序 #12。成就/天赋/结局系统在运行时通过 ProgressionSystem 直写 API 访问跨局数据——SaveLoadSystem 通过信号被动响应持久化，不主动调用 ProgressionSystem 方法 |

## 上下文

### 问题陈述

游戏有 4 个元系统需要跨局持久化数据：

1. **成就系统**（achievement-system.md）：62 个成就的解锁状态、进度追踪（跨局累计型 25 个）、解锁时间戳。数据量 <10KB。
2. **轮回天赋系统**（reincarnation-talent-system.md）：20 个天赋节点的解锁状态、轮回点余额（累计 333 点总成本）、每局槽位装备配置（N = 5 + floor(unlocked/4)）。数据量 <5KB。
3. **结局分支系统**（ending-branch-system.md）：6 个结局的解锁状态、每结局的章节选择路径和历史数据。数据量 <3KB。
4. **卡牌图鉴**（card-system.md）：222 张卡牌的全局发现状态（跨局累计去重）。数据量 <5KB。
5. **游戏统计**（跨系统）：累计战斗次数/胜利、最高伤害、总游戏时间等。数据量 <2KB。

目前 ADR-0001 将 `progression.*` 域的运行时所有权分配给 GSM，SaveLoadSystem 通过 `GSM.progression_updated` 信号被动响应持久化到 `progression.dat`（ADR-0002）。但此模型存在三个结构性问题：

- **生命周期错配**：`progression` 数据跨局持久存在——`new_game()` 从不重置它。但 GSM 的 `serialize()` 明确排除 `battle` 和 `session` 域，而 `progression` 数据与单局存档数据混在同一个序列化输出中。这造成概念混淆——"哪些数据随存档重置，哪些不随？"
- **写入路径分散**：已注册为 `progression.*` 拥有者的 GSM（ADR-0001）实际上并不理解 achievement/talent/ending 的内部结构——它只是一个被动的字典容器。当 AchievementSystem 写入 `achievements.unlocked` 时，它通过 GSM 第二层方法（`GSM.set_progression_flag()` 或直接字典操作）写入，但 GSM 不校验成就 ID 是否存在或进度值是否有效。校验逻辑分散在 4 个特征系统中。
- **3 个 GDD 各自定义自己的持久化需求**：成就系统假定 `progression.dat` 中的 `achievements` 子域；轮回天赋系统假定 `progression.dat` 中的 `reincarnation_points` + `unlocked_talents`；结局系统 GDD 最初要求独立的 `endings.dat`。缺乏统一的 schema 权威源，存在域冲突和重复定义的风险。

需要的是一个**专用的协调器**——它拥有 progression 运行时数据，提供按领域结构化的 API，在写入时执行校验，并通过信号委托 SaveLoadSystem 进行被动持久化。

### 约束

- **Autoload 槽位**：已有 11 个 Autoload（GSM→Input→Scene→SaveLoad→Event→Card→Cost→StatusEffect→Combat→CardEffect→Realm）。ProgressionSystem 为第 12 个。
- **初始化顺序**：ProgressionSystem 必须在 SaveLoadSystem（#4）之后初始化——它需要 `progression.dat` 已加载。但必须在任何特征系统（AchievementSystem、ReincarnationSystem）之前就绪——这些系统为非 Autoload，在场景内按需实例化。
- **GSM 解耦**：ProgressionSystem 的数据不经过 GSM——GSM 不再持有 `progression.*` 域。特征系统查询跨局数据时直接访问 ProgressionSystem。
- **SaveLoadSystem 契约**：ProgressionSystem 通过 `progression_updated` 信号触发 SaveLoadSystem 的被动持久化——继承 ADR-0002 的信号驱动被动保存模式（"特征系统不直接调用 SaveLoadSystem"）。
- **JSON 类型兼容性**：`serialize()` 输出必须仅包含 JSON 兼容类型——GSM 不再作为中间层，ProgressionSystem 自行保证类型兼容性。
- **首局默认值**：progression.dat 不存在时为全新玩家——ProgressionSystem 必须从零初始化所有域，不报错。

### 需求

- 6 个领域化数据存储：achievements、talents、card_gallery、endings、statistics、meta
- 每个领域有独立的类型化 API（校验 + 读写）
- 直写缓存模型：写入 API → 内部存储 → `progression_updated` 信号 → SaveLoadSystem 被动持久化
- 统一序列化：`serialize()` / `deserialize()` 用于 SaveLoadSystem 的 progression.dat I/O
- 取代 ADR-0001 中 `progression.*` 域的 GSM 所有权
- 特征系统通过 ProgressionSystem API 访问跨局数据——不通过 GSM

## 决策

**ProgressionSystem 将作为 Godot Autoload 单例（#12）实现，拥有所有跨局元进度运行时数据——使用直写缓存模型（特征系统 → API → 内部存储 → 信号 → SaveLoadSystem 被动持久化）。**

### 架构图

```
┌──────────────────────────────────────────────────────────────┐
│                  ProgressionSystem (Autoload #12)             │
│                                                              │
│  ┌─ 领域存储（运行时，内存中）────────────────────────────┐   │
│  │ _achievements:    Dict[String → AchievementState]      │   │
│  │ _talents:         Dict[String → TalentState]           │   │
│  │ _card_gallery:    Dict[String → bool]                  │   │
│  │ _endings:         Dict[String → EndingState]           │   │
│  │ _statistics:      Dict[String → int]                   │   │
│  │ _meta:            Dict[String → Variant]               │   │
│  │ _dirty:           bool（自上次保存后是否有变更）         │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─ API 层（按领域）────────────────────────────────────┐     │
│  │ achievements.*    talents.*      gallery.*            │     │
│  │ endings.*         stats.*        serialize/deserialize │     │
│  └────────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─ 信号总线 ──────────────────────────────────────────┐     │
│  │ progression_updated(domain, key, old_val, new_val)   │     │
│  │   → SaveLoadSystem 监听 → _atomic_write(progression) │     │
│  │ achievement_unlocked(ach_id) → AchievementUI         │     │
│  │ talent_purchased(id, points_remaining) → TalentTreeUI │     │
│  │ card_discovered(card_id, total) → GalleryUI          │     │
│  │ ending_unlocked(ending_id, total) → GalleryUI        │     │
│  └────────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─ 初始化 ────────────────────────────────────────────┐     │
│  │ _ready() → 初始化空存储                              │     │
│  │ SaveLoadSystem.load_progression() → 直接调用（非信号） │     │
│  │ initialize(data) → 从 progression.dat 填充存储       │     │
│  │ progression_initialized 信号 → 特征系统 now usable    │     │
│  └────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
         ▲                              │
         │ 读取 + 写入（API）             │ progression_updated 信号
    ┌────┴──────────────────┐     ┌─────┴──────────────┐
    │ 特征系统（非 Autoload）  │     │ SaveLoadSystem      │
    │ AchievementSystem      │     │ → _atomic_write(    │
    │ ReincarnationSystem    │     │     progression.dat) │
    │ EndingBranchSystem     │     └────────────────────┘
    │ CardSystem (gallery)   │
    └────────────────────────┘
```

### 关键接口

```
# === 成就领域 ===
ProgressionSystem.unlock_achievement(ach_id: String) → {success: bool, reason: String}
  # 仅在未解锁时成功。写入 unlocked_at=ISO-8601 时间戳。
  # 发射 achievement_unlocked(ach_id)。失败原因：'already_unlocked' | 'unknown_id'

ProgressionSystem.get_achievement(ach_id: String) → Dictionary
  # 返回 {id, name, unlocked, unlocked_at, progress: {current, target}|null}

ProgressionSystem.get_achievements(category: String = "") → Array[Dictionary]
  # category="" 时返回全部 62 个——按 unlocked_at DESC 排序（已解锁优先）

ProgressionSystem.update_achievement_progress(ach_id: String, increment: int) → void
  # 跨局累计型成就的进度递增。达到 target 时自动调用 unlock_achievement()
  # 单局成就（progress==null）调用此方法无操作

# === 天赋领域 ===
ProgressionSystem.get_talent_points() → int
  # 返回 progression._talents["points_available"]

ProgressionSystem.add_talent_points(amount: int) → void
  # 轮回结算时由 ReincarnationSystem 调用。发射 progression_updated

ProgressionSystem.purchase_talent(talent_id: String) → {success: bool, reason: String}
  # 成功：扣除轮回点，写入 unlocked_talents 列表，发射 talent_purchased
  # 失败原因：'insufficient_points' | 'prerequisite_locked' | 'already_unlocked' | 'condition_not_met' | 'unknown_id'

ProgressionSystem.grant_talent(talent_id: String) → {success: bool, reason: String}
  # 直接授予天赋（不扣除轮回点）——用于 EventSystem GAIN_TALENT Outcome 和特殊事件奖励
  # ADR-0003 EventSystem.apply_outcomes() 中 OutcomeType.GAIN_TALENT 的迁移目标
  # 如果天赋已解锁则无操作并返回 success: true（幂等）

ProgressionSystem.get_talent_tree_state() → Dictionary
  # 返回完整天赋树状态：{unlocked: [ids], equipped: [ids], points, slots, branches: {branch: layer}}}

ProgressionSystem.set_equipped_talents(ids: Array[String]) → {success: bool, reason: String}
  # 每局开始时校验槽位数（N = 5 + floor(unlocked_count/4)）。超出槽位数则失败

ProgressionSystem.get_active_slot_count() → int
  # 返回 N = 5 + floor(total_unlocked_talents / 4)

# === 卡牌图鉴领域 ===
ProgressionSystem.mark_card_discovered(card_id: String) → void
  # CardSystem 在玩家首次获得某卡牌时调用。去重——已发现的卡牌不发射信号

ProgressionSystem.is_card_discovered(card_id: String) → bool

ProgressionSystem.get_card_gallery_stats() → Dictionary
  # 返回 {total_discovered: int, total_cards: int (222), completion_pct: float}

# === 结局图鉴领域 ===
ProgressionSystem.unlock_ending(ending_id: String, chapter_path: Dictionary, identity_id: String, realm: String) → {success: bool, reason: String}
  # EndingBranchSystem 在通关展示时序中调用。
  # 原子写入：unlock ending + increment _meta.total_completions + emit ending_unlocked
  # 调用方不必额外调用 set_meta("total_completions", ...)——此方法内置递增
  # 失败原因：'already_unlocked' | 'unknown_ending_id'

ProgressionSystem.get_unlocked_endings() → Array[String]
  # 返回已解锁 ending_id 的数组（最多 6 个）

ProgressionSystem.has_ending(ending_id: String) → bool

ProgressionSystem.get_ending_detail(ending_id: String) → Dictionary
  # 返回 {id, name, unlocked, unlocked_at, chapter_path, identity, realm}

# === 统计领域 ===
ProgressionSystem.increment_stat(key: String, amount: int = 1) → void
  # 跨局累计统计——仅支持 int 值
  # 调用方：CombatSystem 在 battle_ended 后调用 increment_stat("total_battles")；
  #         CombatSystem 在有胜利时调用 increment_stat("total_victories")

ProgressionSystem.set_stat(key: String, value: int) → void
  # 设置绝对值（如 set_stat("highest_damage", 999) 仅在 value > 当前值时写入）
  # 调用方：战斗系统/EndingBranchSystem 在游戏结束时将单局统计提升为永久统计
  # 数据流：CombatSystem 读取 GSM.battle.max_damage_this_run →
  #         ProgressionSystem.set_stat("highest_damage", value)
  # 调用时刻：battle_ended 之后、game_victory/game_over 序列中
  # 单局 vs 永久边界：单局统计在 GSM.battle.* 域中（每局重置）；
  #                   永久统计在 ProgressionSystem._statistics 中（跨局累积）

# === 元信息领域 ===
ProgressionSystem.get_meta(key: String) → Variant
ProgressionSystem.set_meta(key: String, value: Variant) → void
  # 仅特定 key 可写入：'highest_realm_ever' | 'total_reincarnations' | 'total_playtime_seconds' | 'total_completions'

# === 序列化（供 SaveLoadSystem 使用）===
ProgressionSystem.serialize() → Dictionary
  # 返回全量 progression 数据的 JSON 兼容 Dictionary（~25KB）
  # 不包含 _dirty 标志

ProgressionSystem.deserialize(data: Dictionary) → bool
  # 从 progression.dat 的已解析 JSON 填充所有 6 个域
  # 缺失字段 → 默认值填充（向前兼容）
  # 返回 false（数据损坏不可恢复）

ProgressionSystem.has_unsaved_changes() → bool
  # 返回 _dirty 标志——SaveLoadSystem 用于确定是否需要写入

ProgressionSystem.mark_saved() → void
  # SaveLoadSystem 在成功写入后调用——设置 _dirty = false

# === 生命周期 ===
ProgressionSystem.initialize(data: Dictionary) → void
  # 由启动序列调用（在 SaveLoadSystem.load_progression() 成功或默认值之后）
  # 填充所有 6 个存储域 → 连接 progression_updated 信号 → 发射 progression_initialized
```

### progression_updated 信号设计

```
signal progression_initialized()
  # ProgressionSystem._ready() 完成 + 数据填充后发射。特征系统在此信号后安全查询

signal progression_updated(domain: String, key: String, old_val, new_val)
  # 在任何写入后发射。SaveLoadSystem 连接此信号 → 设置 _dirty → 被动直写
  # domain: "achievements" | "talents" | "gallery" | "endings" | "stats" | "meta"
  # 信号去重：同一域在同一帧内的多次写入 → 仅最后一次发射（与 GSM batch_updated 机制一致）
  # ⚠️ Godot 信号发射是同步的——SaveLoadSystem 的回调在当前调用栈中执行 _atomic_write()
  #    单次写入的帧尖峰约 50ms。通过 batch_update_begin/end 减少频繁写入的尖峰累积
```

### 批量更新 API（性能保护）

```
ProgressionSystem.batch_update_begin() → void
  # 暂缓 progression_updated 信号发射。嵌套调用增加计数器

ProgressionSystem.batch_update_end() → void
  # 计数器归零时一次性发射 progression_updated（合并所有域的所有变更）
  # 用于战斗结算（多次 increment_stat）或成就批量检测（多个 update_achievement_progress）

# 使用示例：
#   ProgressionSystem.batch_update_begin()
#   ProgressionSystem.increment_stat("total_battles")
#   ProgressionSystem.increment_stat("total_victories")
#   ProgressionSystem.set_stat("highest_damage", 999)
#   ProgressionSystem.batch_update_end()  # ← 仅在此处发射一次 progression_updated
```

### 域存储声明（类型化 Dictionary）

```gdscript
# GDScript 4.x 类型化 Dictionary——嵌套值类型由 API 方法校验
var _achievements: Dictionary = {}    # Dict[String, AchievementState]
var _talents: Dictionary = {}         # Dict[String, TalentState]
var _card_gallery: Dictionary = {}    # Dict[String, bool]
var _endings: Dictionary = {}         # Dict[String, Dictionary]
var _stats: Dictionary = {}           # Dict[String, int]
var _meta: Dictionary = {}            # Dict[String, Variant]
var _dirty: bool = false
var _batch_depth: int = 0
var _initialized_and_loaded: bool = false
```

### Autoload 初始化顺序

```
#1 GSM → #2 Input → #3 Scene → #4 SaveLoad → #5 Event → #6 Card → 
#7 Cost → #8 StatusEffect → #9 Combat → #10 CardEffect → #11 Realm → #12 Progression
```

**初始化策略：利用 Godot Autoload 顺序 _ready() 保证**

Godot 的 Autoload 按照 `project.godot` 的 `[autoload]` 部分定义顺序**同步顺序**执行 `_ready()`。ProgressionSystem 在位置 #12 执行 `_ready()` 时，SaveLoadSystem（#4）和 GSM（#1）早已完成 `_ready()`。因此**不能使用信号等待模式**——GSM 和 SaveLoadSystem 在位置 #1/#4 发射的信号在位置 #12 的连接前就已发射，ProgressionSystem 将永远收不到这些信号。

**采用直接调用模式**——利用顺序执行保证：

```gdscript
# ProgressionSystem._ready()（Autoload #12）
func _ready():
    _init_empty_stores()
    # SaveLoadSystem._ready() already completed (Autoload #4 < #12)
    # Direct call — no signal waiting needed
    var data = SaveLoadSystem.load_progression()
    initialize(data)
    _initialized_and_loaded = true
    progression_initialized.emit()
```

**启动时序：**

```
① SaveLoadSystem._ready()（Autoload #4）
   → 读取 progression.dat（如果存在），校验 JSON 完整性
   → 缓存已解析的 Dictionary（内存中）
   → 设置 is_loaded = true

② ProgressionSystem._ready()（Autoload #12）
   → 初始化 6 个空领域存储（均为空 Dictionary）
   → 直接调用 SaveLoadSystem.load_progression() → data
     · progression.dat 存在：已解析的 Dictionary
     · 首局（不存在）：默认值（全域为空/零值）
   → initialize(data) 填充全部 6 个存储域
   → 连接 progression_updated → SaveLoadSystem._on_progression_changed()
   → _dirty = false
   → 发射 progression_initialized

③ 特征系统（AchievementSystem、ReincarnationSystem 等）现在可安全查询 ProgressionSystem
   → 它们在各自场景 _ready() 中检查 ProgressionSystem._initialized_and_loaded
```

**为什么不用信号等待**：Godot 信号是同步的，不会为后来的连接者重放。Autoload #12 连接 Autoload #1/#4 在各自 `_ready()` 中发射的信号时，信号早已发射完毕——连接者将永远等待。直接调用利用 Godot 的顺序 `_ready()` 保证——不与此保证对抗。

### 与 ADR-0001 的冲突解决

ADR-0001 §state_ownership 当前将 `progression.*` 域运行时所有权分配给 GSM：
> `entity: progression.* 域（跨局元进度） → owner: game-state-manager（运行时），save-load-system（持久化）`

**本 ADR 取代该所有权条目：**

- **之前**：GSM 在运行时持有 `player.progression.*` 字典
- **之后**：ProgressionSystem 内部持有全部 progression 数据；GSM 不再拥有 `progression` 域
- **理由**：跨局数据与单局游戏状态具有根本不同的生命周期——`progression` 跨局持续存在，`new_game()` 从不重置它。将其保留在 GSM 中混淆了两个不同的数据生命周期，并迫使 GSM 成为它不理解的数据的被动容器。专用系统在写入时提供校验（有效的成就 ID、足够的天赋点数、合法的 ending_id），而 GSM 作为泛型字典容器无法提供这些校验。
- **ADR-0001 修正**：ADR-0001 §state_ownership 的 `progression.*` 条目状态设为 `superseded_by: ADR-0012`

### 与 ADR-0002 的信号源变更

ADR-0002 §api_decisions 确立了 `SaveLoadSystem` 监听 `GSM.progression_updated` 信号的被动保存模式。本 ADR 将 progression 数据所有权从 GSM 迁移到 ProgressionSystem——信号源随所有权转移：

- **之前**：SaveLoadSystem 监听 `GSM.progression_updated` → 触发 `_atomic_write(progression.dat)`
- **之后**：SaveLoadSystem 监听 `ProgressionSystem.progression_updated` → 触发 `_atomic_write(progression.dat)`
- **理由**：信号源遵循数据所有权。ProgressionSystem 是 progression 数据的唯一权威源——只有它知道数据何时变更。GSM 不再持有 progression 数据，因此无法发射该信号。
- **ADR-0002 修正**：ADR-0002 §api_decisions 的 `progression_updated` 监听目标从 `GSM` 变更为 `ProgressionSystem`

## 考虑的替代方案

### 替代方案 A：GSM 被动容器 + 分散写入者（维持现状）

- **描述**：GSM 继续持有 `progression.*` 域。AchievementSystem、ReincarnationSystem、EndingBranchSystem 各自通过 GSM 第二层方法直接写入其子域。不引入新 Autoload。
- **优点**：无新 Autoload；比 ADR-0001 变更更少；特征系统不需要学习新 API
- **缺点**：GSM 作为被动容器不提供域级校验（有效成就 ID、足够轮回点、合法 ending_id）——校验逻辑分散在 3 个系统中。`progression.*` 数据与单局游戏状态混在同一序列化输出中。3 个 GDD 各自独立定义 progression 子域 schema——无统一权威源，存在键冲突风险。`new_game()` 必须显式记住不重置 `progression.*`——这是一个脆弱的隐式约束。
- **拒绝原因**：生命周期错配是根本性的，而非表面性的。跨局数据和单局数据是两种不同的东西——将它们混入同一个容器就像将银行账户余额与当前购物车混在一起。"无新 Autoload"的优势被 schema 漂移和缺乏校验的风险所压倒。

### 替代方案 B：SaveLoadSystem 作为 progression 的完全所有者

- **描述**：SaveLoadSystem 同时拥有 progression 的持久化 I/O 和运行时状态。特征系统调用 `SaveLoadSystem.get_progression(key)` / `SaveLoadSystem.set_progression(key, value)`。不引入新 Autoload。
- **优点**：SaveLoadSystem 已经是 progression.dat 的拥有者（ADR-0003）——扩展到运行时所有权是自然的。持久化和运行时在同一处。
- **缺点**：SaveLoadSystem 的主要职责是 I/O（文件读写、版本管理、原子写入），而非域建模。添加成就校验、天赋树逻辑和结局图鉴管理将使其成为上帝对象（I/O + 4 个元系统的域逻辑）。`set_progression(key, value)` 再次成为缺乏校验的泛型键值存储。
- **拒绝原因**：SaveLoadSystem 是持久化管道，而非域协调器。混合这两个职责违反了关注点分离原则。ProgressionSystem 作为专用协调器是更清晰的分离——它拥有*什么*（数据结构和约束），SaveLoadSystem 处理*如何*（磁盘 I/O）。

### 替代方案 C：每个元系统内部持久化自己的数据

- **描述**：不设 progression.dat。AchievementSystem 写入 `user://achievements.json`；ReincarnationSystem 写入 `user://talents.json`；EndingBranchSystem 写入 `user://endings.json`。各系统通过自己的文件 I/O 管理持久化。
- **优点**：完全去中心化——每个系统独立演进而不与其他系统冲突。无需协调器。
- **缺点**：3-4 个独立的 JSON 文件，各自处理版本管理和损坏恢复。首局启动需要协调多个文件的默认值。删除 progression 数据需要删除多个文件而非一个。相互依赖（成就检查天赋点数、结局检查轮回次数）需要跨文件读取——这破坏了封装性。SaveLoadSystem 的原子写入保证必须跨多个文件复制。
- **拒绝原因**：过度去中心化会导致重复的 I/O 逻辑、版本管理和损坏恢复——每个元系统都重新实现 SaveLoadSystem 已经做好的事情。progression.dat 作为单一触点已经在 ADR-0002 中被接受——本 ADR 只是改变了*谁构建数据*，而非数据存储在哪里。

## 后果

### 积极的

- **清晰的关注点分离**：ProgressionSystem 拥有所有跨局数据——GSM 不再困惑于"这个域会随存档重置吗？"。运行时职责边界明确：ProgressionSystem = 跨局数据，GSM = 单局数据。
- **写入时校验**：`unlock_achievement("ach_invalid")` 在 ProgressionSystem 层被捕获——返回 `{success: false, reason: "unknown_id"}`。不再有静默写入无效成就 ID 到字典的情况。
- **统一 schema 权威源**：6 个领域在 ProgressionSystem 内部定义——GDD 引用 ProgressionSystem API 作为权威接口，而非各自独立定义持久化 schema。
- **继承的信号驱动持久化模式**：与 ADR-0002 的模式一致——"特征系统不直接调用 SaveLoadSystem"。只有 ProgressionSystem 的 `progression_updated` 信号触发持久化。
- **存档系统更简单**：`new_game()` 不触及 progression——GSM 重置单局状态，ProgressionSystem 不变。`delete_save()` 仅删除存档槽位——progression 保持原样。消除了"记住不重置 progression"的隐式约束。
- **GDD 需求可追溯**：所有 4 个元系统的 GDD 需求均可链接到 ProgressionSystem API 中的特定方法。

### 消极的

- **Autoload #12**：ProgressionSystem 是第 12 个 Autoload——增加了初始化顺序的复杂性。缓解措施：初始化顺序文档化清晰（在 SaveLoadSystem（#4）之后，在特征系统（场景内）之前）。直接调用模式（非信号等待）利用 Godot 顺序 `_ready()` 保证——在 12 个 Autoload 的已知安全阈值（<20）内。Autoload 数量应纳入技术债务跟踪——未来 ADR 在新增 Autoload 时必须明确论证必要性。
- **GSM 域所有权变更**：ADR-0001 需要修订（`progression.*` 条目状态设为 `superseded_by: ADR-0012`）。错误处理：架构注册表更新需此协商——`progression.*` 条目不会消失，而是标记为已取代。
- **API 表面积**：ProgressionSystem 暴露 ~25 个公共方法（6 个领域）。与 GSM 的泛型 `set()` 相比体积更大——但每个方法小巧且专注。缓解措施：每个领域的 API 按职责清晰分组——消费者系统仅使用其相关领域。
- **`endings.dat` 合并**：结局分支系统 GDD 要求独立 `endings.dat` 以保证持久化独立性。本 ADR 将结局图鉴数据合并入 ProgressionSystem→progression.dat。缓解措施：progression.dat 的 `.bak` 备份 + 原子写入策略已提供写入安全性——独立文件不是必需的。
- **结构化错误返回与 GSM 风格差异**：ProgressionSystem 使用 `{success: bool, reason: String}` 结构化返回值，而 GSM 使用简单的 `bool`。这是**有意的模式选择**——失败原因（`"insufficient_points"`、`"prerequisite_locked"`）是 UI 需要展示的用户可见信息，并非 GSM 的系统级错误。GSM 的 `bool` 返回适用于系统操作（"资源添加成功了吗？"），ProgressionSystem 的 `{success, reason}` 适用于领域操作（"为什么天赋无法购买？"）。详见 §错误传播设计。
- **Godot 4.6 双焦点系统**：监听 `achievement_unlocked` / `card_discovered` 信号的 UI `Control` 节点（AchievementUI、GalleryUI）需处理 4.6 的双焦点（鼠标焦点 ≠ 键盘焦点）——不影响此 Autoload，但 UI 实现需注意。作为实施注意事项记录于此。

### 风险

- **progression.dat 损坏导致所有跨局进度丢失**：5 个领域的数据在一次文件损坏中全部归零——成就、天赋、图鉴、结局、统计。缓解措施：(a) 原子写入策略（.tmp → rename）将损坏风险降至最低——详见 ADR-0002；(b) 损坏检测时保留 `.bak` 备份；(c) Steam Cloud 作为远程备份（若上架 Steam）；(d) 成就总数 62 在同一文件中——部分损坏极小可能。
- **Godot 同步信号发射导致帧尖峰**：`progression_updated` 信号触发 SaveLoadSystem 的 `_atomic_write()` ——该调用在当前调用栈中同步执行，约 50ms 磁盘 I/O 直接加到帧上。缓解措施：(a) 批量更新 API（`batch_update_begin/end`）将多次统计增量合并为一次信号发射；(b) SaveLoadSystem 内部防抖——每 5 秒最多一次写盘或退出时最后一次写盘；(c) 对于 `WorkerThreadPool` 的未来评估（Godot 4.6 中 FileAccess 非线程安全——需要完整的序列化到线程安全缓冲区+工作线程 I/O，增加了显著复杂度）。在 MVP 中接受帧尖峰——progression 写入为低频事件（跨局累计），不会每帧发生。
- **Autoload 初始化顺序错误**：ProgressionSystem._ready() 在 progression.dat 被加载前运行——特征系统可能在 `initialize()` 被调用前查询空存储。缓解措施：ProgressionSystem 在所有域存储填充完成前设置 `_initialized_and_loaded = false`。消费者在查询前检查此标志。Godot 的 Autoload _ready() 顺序严格遵循 Project Settings——顺序在编码前即已知。直接调用模式（在 _ready() 中调用 SaveLoadSystem.load_progression()）保证了在 _ready() 返回前数据已填充——消除了信号等待的竞态条件（godot-specialist 审查 H-1 已解决）。

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| achievement-system.md | §4.3 跨局累计型成就——进度存储在 `progression.achievements` 中，跨局永不重置 | `_achievements` 域存储 + `update_achievement_progress()` 累计递增 |
| achievement-system.md | §7 成就数据持久化——成就解锁时立即写入 progression.dat | `unlock_achievement()` → `progression_updated` 信号 → SaveLoadSystem 被动持久化 |
| achievement-system.md | §6 成就与轮回天赋单向数据流——成就可检查天赋解锁数量 | ProgressionSystem API：`get_talent_tree_state()` 被 AchievementSystem 读取 |
| reincarnation-talent-system.md | §4 轮回点存储与消费——存储在 `progression.reincarnation_points` 中，持久化到 progression.dat | `_talents` 域存储 + `add_talent_points()` / `purchase_talent()` 写入 |
| reincarnation-talent-system.md | §5 天赋生效时机——每局开始时通过槽位选择自动应用已装备天赋 | `_talents.equipped` 读取（场景内系统在各自 _ready() 中查询） |
| reincarnation-talent-system.md | §8 轮回结算中新卡牌解锁——解锁检测写入 progression | `check_card_unlocks()` 通过 ProgressionSystem API 访问累积统计 |
| ending-branch-system.md | §5 结局图鉴——所有已解锁结局的独立持久化存储 | `_endings` 域集成到 ProgressionSystem：`unlock_ending()` 写入 |
| ending-branch-system.md | §6 结局对后续游戏的影响——写入 `progression.endings_unlocked` 和 `progression.total_completions` | `_meta.total_completions` 由 `unlock_ending()` 中的 EndingBranchSystem 递增 |
| card-system.md | 全局图鉴——跨局累计卡牌发现 | `_card_gallery` 域 + `mark_card_discovered()` → CardSystem 在首次获得卡牌时调用 |
| save-load-system.md | progression.dat——独立跨局元进度文件，player.* 外 | `serialize()` / `deserialize()` 供 SaveLoadSystem 使用——统一 schema |
| save-load-system.md | §7 跨局元进度读写——从 GSM progression 域读写 | 取代——ProgressionSystem 是唯一所有者。GSM 不再持有 progression 数据 |
| game-state-manager.md | §详细设计——GSM 三层架构中包含 progression 域 | 取代——`progression.*` 域从 GSM 中移除，迁移到 ProgressionSystem |

## 性能影响

- **CPU**：所有写入为事件驱动（成就解锁、天赋购买、统计递增）——无每帧工作量。信号去重（每域每帧最多一次 `progression_updated` 发射）+ 批量更新 API（`batch_update_begin/end`）在高频场景（战斗结算的多统计增量）下防止帧尖峰累积。SaveLoadSystem 的被动持久化为同步的——`progression_updated` 信号发射在当前调用栈中执行 `_atomic_write()`（约 50ms 磁盘 I/O）。单次写入（成就解锁）的尖峰可接受；高频场景通过批量更新合并为一次写盘。SaveLoadSystem 额外防抖写入（每 5 秒最多一次，或游戏退出前最后一次）。
- **内存**：完整 progression 运行时状态 <100KB（62 成就 + 20 天赋 + 222 布尔 + 6 结局 + ~15 统计键 + 元信息）。所有存储为 Dictionary —— O(1) 访问。
- **加载时间**：ProgressionSystem._ready() 为瞬时（初始化空字典）。`initialize()` 从 ~25KB Dictionary 填充——<1ms。SaveLoadSystem 仅在 `progression.dat` 已存在时调用 `initialize(data)`，否则使用默认值。
- **网络**：不适用（纯单机游戏）。

## 迁移计划

1. **ADR-0001 修订**：`progression.*` 域所有权条目状态设为 `superseded_by: ADR-0012`。GSM 移除 `progression` 域（无现有代码需重构——pre-production）。
2. **ADR-0002 修订**：`api_decisions` 第 348-352 行 `"监听 GSM.progression_updated"` → `"监听 ProgressionSystem.progression_updated"`。迁移目标与 §"与 ADR-0002 的信号源变更" 一致。
3. **架构注册表更新**：
   - `state_ownership` 第 64-69 行：`progression.*` 域条目——所有权从 `game-state-manager` 变更为 `progression-system`，status 设为 `superseded_by: ADR-0012`
   - `state_ownership` 新增：ProgressionSystem 的 6 个域条目（achievements、talents、card_gallery、endings、statistics、meta）
   - `api_decisions` 第 348-352 行：`"监听 GSM.progression_updated"` → `"监听 ProgressionSystem.progression_updated"`
4. **SaveLoadSystem 接口调整**：`save_progression()` 和 `load_progression()` 改为与 ProgressionSystem（而非 GSM）对接。调用 `ProgressionSystem.serialize()` / `deserialize()` 替代 `GSM.progression` 域访问。
5. **EventSystem GAIN_TALENT 适配**：ADR-0003 的 `apply_outcomes()` 中 `OutcomeType.GAIN_TALENT` 当前调用 `GSM.progression.unlock_talent()`。迁移后改为调用 `ProgressionSystem.grant_talent(talent_id)`——此方法直接授予天赋（不消耗轮回点），匹配事件奖励语义。
6. **特征系统适配**：AchievementSystem、ReincarnationSystem、EndingBranchSystem、CardSystem（图鉴）将其 progression 数据访问从 GSM（如适用）改为 ProgressionSystem API。

## 验证标准

- 通过 GUT：ProgressionSystem 测试套件覆盖：全部 6 个领域的 API 方法、写入时校验拒绝无效 ID、`serialize()` / `deserialize()` 往返保真度、首局默认值初始化、`progression_updated` 信号去重（同域同帧多次写入仅发射一次）、`has_unsaved_changes()` 标志正确性、槽位计算（N = 5 + floor(unlocked/4)）、`grant_talent()` 幂等性（重复授予同一天赋）、`unlock_ending()` 内置 `total_completions` 递增
- 通过集成：SaveLoadSystem 调用 `ProgressionSystem.serialize()` → 写入 progression.dat → `ProgressionSystem.deserialize()` → 数据一致
- 通过集成：`unlock_achievement("ach_first_realm_break")` → `progression_updated` 信号发射 → SaveLoadSystem 接收并写入
- 通过集成：CombatSystem 在 `battle_ended` 后调用 `increment_stat("total_battles")` + `set_stat("highest_damage", gsm_battle_max)` → 统计域正确更新

## 错误传播设计

ProgressionSystem 使用 `{success: bool, reason: String}` 结构化返回值（而非 GSM 的简单 `bool`）。这是**有意的模式选择**：

| 对比维度 | GSM `bool` | ProgressionSystem `{success, reason}` |
|---------|-----------|--------------------------------------|
| **用例** | 系统级操作——"资源添加成功了吗？" | 领域级操作——"为什么天赋无法购买？" |
| **失败信息消费者** | 调用系统（日志警告，自动处理） | 终端用户（UI 展示失败原因） |
| **示例** | `add_resource("灵石", -50)` → false（余额不足） | `purchase_talent("darkgold_3")` → {false, "prerequisite_locked"} |
| **UI 需求** | 无——系统错误由调用方自行处理 | 是——`reason` 直接渲染到天赋树 UI 提示文本 |

`mark_card_discovered()` 和 `increment_stat()` 的 `void` 返回合理——这些操作不会发生有意义业务故障（幂等去重，无前置条件）。结构化返回值仅用于可能因用户可见原因而失败的 API（成就解锁、天赋购买、结局解锁、槽位设置）。

## 相关决策

- ADR-0001（GSM——`progression.*` 域生命周期从此 ADR 解耦）
- ADR-0003（SaveLoadSystem——progression.dat 的持久化管道——ProgressionSystem 是数据权威源，SaveLoadSystem 是 I/O 层）
- ADR-0007（信号分类——本 ADR 的 Cat 2b 信号符合三分类体系）
- 尚未编写的 ADR：成就系统 ADR、轮回天赋系统 ADR、结局分支系统 ADR（均为该领域的实现层决策）
